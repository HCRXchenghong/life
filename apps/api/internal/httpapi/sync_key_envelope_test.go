package httpapi

import (
	"encoding/base64"
	"testing"
)

func validContentKeyEnvelopeInput() contentKeyEnvelopeInput {
	return contentKeyEnvelopeInput{
		KeyVersion: 1, Algorithm: "aes-256-gcm", KDF: "hkdf-sha256",
		Salt:            base64.StdEncoding.EncodeToString(make([]byte, 32)),
		Nonce:           base64.StdEncoding.EncodeToString(make([]byte, 12)),
		Ciphertext:      base64.StdEncoding.EncodeToString(make([]byte, 48)),
		CreatorDeviceID: "9b276a3e-b141-4d91-8dbf-0f217b62b071",
	}
}

func TestDecodeContentKeyEnvelopeRequiresExactCryptographicShape(t *testing.T) {
	input := validContentKeyEnvelopeInput()
	decoded, err := decodeContentKeyEnvelope(input)
	if err != nil || len(decoded.Ciphertext) != 48 {
		t.Fatalf("expected valid envelope, got %#v, %v", decoded, err)
	}

	cases := []struct {
		name   string
		mutate func(*contentKeyEnvelopeInput)
	}{
		{"algorithm", func(value *contentKeyEnvelopeInput) { value.Algorithm = "aes-gcm" }},
		{"kdf", func(value *contentKeyEnvelopeInput) { value.KDF = "pbkdf2" }},
		{"version", func(value *contentKeyEnvelopeInput) { value.KeyVersion = 2 }},
		{"device", func(value *contentKeyEnvelopeInput) { value.CreatorDeviceID = "../device" }},
		{"salt", func(value *contentKeyEnvelopeInput) { value.Salt = base64.StdEncoding.EncodeToString(make([]byte, 31)) }},
		{"nonce", func(value *contentKeyEnvelopeInput) {
			value.Nonce = base64.StdEncoding.EncodeToString(make([]byte, 11))
		}},
		{"ciphertext", func(value *contentKeyEnvelopeInput) {
			value.Ciphertext = base64.StdEncoding.EncodeToString(make([]byte, 47))
		}},
		{"base64", func(value *contentKeyEnvelopeInput) { value.Ciphertext = "not-base64" }},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			candidate := validContentKeyEnvelopeInput()
			test.mutate(&candidate)
			if _, err := decodeContentKeyEnvelope(candidate); err == nil {
				t.Fatal("expected malformed envelope to be rejected")
			}
		})
	}
}

func TestSameContentKeyEnvelopeRejectsAnySubstitution(t *testing.T) {
	first, err := decodeContentKeyEnvelope(validContentKeyEnvelopeInput())
	if err != nil {
		t.Fatal(err)
	}
	second := first
	second.Ciphertext = append([]byte(nil), first.Ciphertext...)
	second.Ciphertext[0] = 1
	if sameContentKeyEnvelope(first, second) {
		t.Fatal("changed ciphertext must not be treated as idempotent")
	}
}
