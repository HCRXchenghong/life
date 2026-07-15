package config

import (
	"encoding/base64"
	"testing"

	"github.com/go-sql-driver/mysql"
)

func TestMySQLDSNPreservesRandomPassword(t *testing.T) {
	t.Setenv("MYSQL_DSN", "")
	t.Setenv("MYSQL_HOST", "mysql")
	t.Setenv("MYSQL_PORT", "3306")
	t.Setenv("MYSQL_DATABASE", "daylink")
	t.Setenv("MYSQL_USER", "daylink")
	t.Setenv("MYSQL_PASSWORD", "p@ss:/?#[]! with spaces")
	raw, err := mysqlDSN()
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := mysql.ParseDSN(raw)
	if err != nil {
		t.Fatal(err)
	}
	if parsed.Passwd != "p@ss:/?#[]! with spaces" || parsed.Addr != "mysql:3306" {
		t.Fatal("MySQL connection settings changed during formatting")
	}
}

func TestLoadRejectsLookalikeLoopbackOrigin(t *testing.T) {
	authKey := base64.StdEncoding.EncodeToString(make([]byte, 32))
	aiBytes := make([]byte, 32)
	aiBytes[0] = 1
	t.Setenv("AUTH_SECRET_MASTER_KEY", authKey)
	t.Setenv("AI_SECRET_MASTER_KEY", base64.StdEncoding.EncodeToString(aiBytes))
	t.Setenv("MYSQL_DSN", "")
	t.Setenv("MYSQL_PASSWORD", "test-only")
	t.Setenv("PUBLIC_ORIGIN", "http://localhost.example.com")
	if _, err := Load(); err == nil {
		t.Fatal("insecure lookalike loopback origin accepted")
	}
}

func TestLoadRequiresProductionSetupToken(t *testing.T) {
	authBytes := make([]byte, 32)
	authBytes[0] = 1
	aiBytes := make([]byte, 32)
	aiBytes[0] = 2
	t.Setenv("AUTH_SECRET_MASTER_KEY", base64.StdEncoding.EncodeToString(authBytes))
	t.Setenv("AI_SECRET_MASTER_KEY", base64.StdEncoding.EncodeToString(aiBytes))
	t.Setenv("MYSQL_DSN", "")
	t.Setenv("MYSQL_PASSWORD", "test-only")
	t.Setenv("PUBLIC_ORIGIN", "https://daylink.example.com")
	t.Setenv("ADMIN_SETUP_TOKEN", "")
	if _, err := Load(); err == nil {
		t.Fatal("production origin accepted without an administrator setup token")
	}
	t.Setenv("ADMIN_SETUP_TOKEN", "separate-bootstrap-token-123")
	if _, err := Load(); err != nil {
		t.Fatalf("valid production setup rejected: %v", err)
	}
}
