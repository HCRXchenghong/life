package security

import (
	"encoding/base64"
	"testing"
	"time"
)

func TestPasswordRoundTripAndDomainSeparation(t *testing.T) {
	key := make([]byte, 32)
	digest, err := HashPassword("Longer!Pass123", "admin", key)
	if err != nil {
		t.Fatal(err)
	}
	if !VerifyPassword("Longer!Pass123", "admin", digest, key) {
		t.Fatal("valid password rejected")
	}
	if VerifyPassword("Longer!Pass123", "app", digest, key) {
		t.Fatal("password digest crossed domains")
	}
	digest.Algorithm = "pbkdf2-sha256-app-v1"
	if VerifyPassword("Longer!Pass123", "admin", digest, key) {
		t.Fatal("unexpected password algorithm accepted")
	}
}

func TestTOTPVectorAndReplay(t *testing.T) {
	secret := base64.StdEncoding.EncodeToString([]byte("12345678901234567890"))
	_ = secret
	base32Secret := "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
	counter, ok := VerifyTOTP(base32Secret, "287082", nil, time.Unix(59, 0))
	if !ok || counter != 1 {
		t.Fatalf("unexpected counter: %d %v", counter, ok)
	}
	if _, replay := VerifyTOTP(base32Secret, "287082", &counter, time.Unix(59, 0)); replay {
		t.Fatal("replayed code accepted")
	}
}

func TestSecretEncryptionUsesPurposeBinding(t *testing.T) {
	key := make([]byte, 32)
	ciphertext, nonce, err := Encrypt(key, "provider:one", []byte("secret"))
	if err != nil {
		t.Fatal(err)
	}
	plaintext, err := Decrypt(key, "provider:one", ciphertext, nonce)
	if err != nil || string(plaintext) != "secret" {
		t.Fatal("round trip failed")
	}
	if _, err := Decrypt(key, "provider:two", ciphertext, nonce); err == nil {
		t.Fatal("ciphertext accepted for another purpose")
	}
	if _, err := Decrypt(key, "provider:one", ciphertext, nonce[:4]); err == nil {
		t.Fatal("invalid nonce size accepted")
	}
}
