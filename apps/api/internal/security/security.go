package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha1" // #nosec G505 -- RFC 6238 compatibility requires HMAC-SHA1.
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"
)

const PasswordIterations = 600_000

var usernamePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{3,31}$`)

type PasswordDigest struct {
	Algorithm  string
	Hash       string
	Salt       string
	Iterations int
}

func ValidateUsername(value string) (string, error) {
	value = strings.TrimSpace(value)
	if !usernamePattern.MatchString(value) {
		return "", errors.New("账号需为 4–32 位字母、数字、点、下划线或连字符")
	}
	return value, nil
}

func ValidateStrongPassword(value string) error {
	if len(value) < 12 || len(value) > 128 {
		return errors.New("密码必须为 12–128 位")
	}
	var lower, upper, digit, symbol bool
	for _, r := range value {
		switch {
		case r >= 'a' && r <= 'z':
			lower = true
		case r >= 'A' && r <= 'Z':
			upper = true
		case r >= '0' && r <= '9':
			digit = true
		default:
			symbol = true
		}
	}
	if !lower || !upper || !digit || !symbol {
		return errors.New("密码必须同时包含大小写字母、数字和符号")
	}
	return nil
}

func HashPassword(password, domain string, masterKey []byte) (PasswordDigest, error) {
	if err := ValidateStrongPassword(password); err != nil {
		return PasswordDigest{}, err
	}
	salt, err := RandomBytes(16)
	if err != nil {
		return PasswordDigest{}, err
	}
	pepper := derive(masterKey, "password:"+domain)
	hash, err := pbkdf2.Key(sha256.New, password+base64.RawStdEncoding.EncodeToString(pepper), salt, PasswordIterations, 32)
	if err != nil {
		return PasswordDigest{}, err
	}
	return PasswordDigest{
		Algorithm:  "pbkdf2-sha256-" + domain + "-v1",
		Hash:       base64.StdEncoding.EncodeToString(hash),
		Salt:       base64.StdEncoding.EncodeToString(salt),
		Iterations: PasswordIterations,
	}, nil
}

func VerifyPassword(password, domain string, digest PasswordDigest, masterKey []byte) bool {
	if len(password) > 128 || digest.Algorithm != "pbkdf2-sha256-"+domain+"-v1" ||
		digest.Iterations < 100_000 || digest.Iterations > 2_000_000 {
		return false
	}
	salt, err := base64.StdEncoding.DecodeString(digest.Salt)
	if err != nil || len(salt) < 16 {
		return false
	}
	want, err := base64.StdEncoding.DecodeString(digest.Hash)
	if err != nil || len(want) != 32 {
		return false
	}
	pepper := derive(masterKey, "password:"+domain)
	got, err := pbkdf2.Key(sha256.New, password+base64.RawStdEncoding.EncodeToString(pepper), salt, digest.Iterations, len(want))
	return err == nil && subtle.ConstantTimeCompare(got, want) == 1
}

func RandomToken(prefix string) (string, error) {
	bytes, err := RandomBytes(36)
	if err != nil {
		return "", err
	}
	return prefix + base64.RawURLEncoding.EncodeToString(bytes), nil
}

func RandomID() (string, error) {
	b, err := RandomBytes(16)
	if err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		binary.BigEndian.Uint32(b[0:4]), binary.BigEndian.Uint16(b[4:6]),
		binary.BigEndian.Uint16(b[6:8]), binary.BigEndian.Uint16(b[8:10]), b[10:16]), nil
}

func RandomBytes(length int) ([]byte, error) {
	b := make([]byte, length)
	_, err := rand.Read(b)
	return b, err
}

func SHA256(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func PrivateHash(masterKey []byte, domain, value string) string {
	mac := hmac.New(sha256.New, derive(masterKey, "private-hash:"+domain))
	_, _ = mac.Write([]byte(value))
	return hex.EncodeToString(mac.Sum(nil))
}

func Encrypt(masterKey []byte, purpose string, plaintext []byte) (ciphertext, nonce []byte, err error) {
	block, err := aes.NewCipher(derive(masterKey, "aes-gcm:"+purpose))
	if err != nil {
		return nil, nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, nil, err
	}
	nonce, err = RandomBytes(gcm.NonceSize())
	if err != nil {
		return nil, nil, err
	}
	return gcm.Seal(nil, nonce, plaintext, []byte(purpose)), nonce, nil
}

func Decrypt(masterKey []byte, purpose string, ciphertext, nonce []byte) ([]byte, error) {
	block, err := aes.NewCipher(derive(masterKey, "aes-gcm:"+purpose))
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(nonce) != gcm.NonceSize() {
		return nil, errors.New("invalid nonce size")
	}
	return gcm.Open(nil, nonce, ciphertext, []byte(purpose))
}

func NewTOTPSecret() (string, error) {
	b, err := RandomBytes(20)
	if err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b), nil
}

func TOTPUri(username, secret string) string {
	label := url.PathEscape("Daylink:" + username)
	values := url.Values{"secret": {secret}, "issuer": {"Daylink"}, "algorithm": {"SHA1"}, "digits": {"6"}, "period": {"30"}}
	return "otpauth://totp/" + label + "?" + values.Encode()
}

func VerifyTOTP(secret, code string, lastCounter *int64, now time.Time) (int64, bool) {
	if len(code) != 6 {
		return 0, false
	}
	for _, r := range code {
		if r < '0' || r > '9' {
			return 0, false
		}
	}
	key, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.ToUpper(secret))
	if err != nil {
		return 0, false
	}
	counter := now.Unix() / 30
	for offset := int64(-1); offset <= 1; offset++ {
		candidate := counter + offset
		if lastCounter != nil && candidate <= *lastCounter {
			continue
		}
		if subtle.ConstantTimeCompare([]byte(totpCode(key, candidate)), []byte(code)) == 1 {
			return candidate, true
		}
	}
	return 0, false
}

func totpCode(key []byte, counter int64) string {
	var message [8]byte
	binary.BigEndian.PutUint64(message[:], uint64(counter))
	mac := hmac.New(sha1.New, key) // #nosec G401 -- RFC 6238 compatibility.
	_, _ = mac.Write(message[:])
	sum := mac.Sum(nil)
	offset := sum[len(sum)-1] & 0x0f
	value := (uint32(sum[offset])&0x7f)<<24 |
		uint32(sum[offset+1])<<16 |
		uint32(sum[offset+2])<<8 |
		uint32(sum[offset+3])
	return fmt.Sprintf("%06d", value%1_000_000)
}

func derive(masterKey []byte, label string) []byte {
	mac := hmac.New(sha256.New, masterKey)
	_, _ = mac.Write([]byte(label))
	return mac.Sum(nil)
}
