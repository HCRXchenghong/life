package httpapi

import (
	"encoding/base64"
	"testing"
)

func TestDecodeDeviceApprovalDecisionRequiresFixedEncryptedPackage(t *testing.T) {
	valid := deviceApprovalDecisionInput{
		ApproverPublicKey: base64.StdEncoding.EncodeToString(repeatedBytes(32, 1)),
		Nonce:             base64.StdEncoding.EncodeToString(repeatedBytes(12, 2)),
		Ciphertext:        base64.StdEncoding.EncodeToString(repeatedBytes(48, 3)),
		KeyVersion:        1,
	}
	decoded, err := decodeDeviceApprovalDecision(valid)
	if err != nil {
		t.Fatalf("expected valid encrypted decision: %v", err)
	}
	if len(decoded.ApproverPublicKey) != 32 || len(decoded.Nonce) != 12 || len(decoded.Ciphertext) != 48 {
		t.Fatal("decoded decision lengths changed")
	}

	tests := []struct {
		name   string
		mutate func(*deviceApprovalDecisionInput)
	}{
		{"zero public key", func(value *deviceApprovalDecisionInput) {
			value.ApproverPublicKey = base64.StdEncoding.EncodeToString(make([]byte, 32))
		}},
		{"short public key", func(value *deviceApprovalDecisionInput) {
			value.ApproverPublicKey = base64.StdEncoding.EncodeToString(repeatedBytes(31, 1))
		}},
		{"short nonce", func(value *deviceApprovalDecisionInput) {
			value.Nonce = base64.StdEncoding.EncodeToString(repeatedBytes(11, 2))
		}},
		{"short ciphertext", func(value *deviceApprovalDecisionInput) {
			value.Ciphertext = base64.StdEncoding.EncodeToString(repeatedBytes(47, 3))
		}},
		{"unsupported key version", func(value *deviceApprovalDecisionInput) { value.KeyVersion = 0 }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			input := valid
			test.mutate(&input)
			if _, err := decodeDeviceApprovalDecision(input); err == nil {
				t.Fatal("expected malformed decision to be rejected")
			}
		})
	}
}

func TestDecodeFixedBase64RejectsNonCanonicalLengths(t *testing.T) {
	if _, err := decodeFixedBase64(base64.StdEncoding.EncodeToString(repeatedBytes(32, 9)), 32); err != nil {
		t.Fatalf("expected valid fixed value: %v", err)
	}
	for _, value := range []string{"", "not-base64", base64.StdEncoding.EncodeToString(repeatedBytes(33, 9))} {
		if _, err := decodeFixedBase64(value, 32); err == nil {
			t.Fatal("expected invalid fixed value to be rejected")
		}
	}
}

func repeatedBytes(length int, value byte) []byte {
	output := make([]byte, length)
	for index := range output {
		output[index] = value
	}
	return output
}
