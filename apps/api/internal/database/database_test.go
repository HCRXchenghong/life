package database

import (
	"testing"
	"time"

	"github.com/go-sql-driver/mysql"
)

func TestEnsureDSNOptionsAppliesSafeDefaults(t *testing.T) {
	raw, err := ensureDSNOptions("daylink:password@tcp(mysql:3306)/daylink")
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := mysql.ParseDSN(raw)
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.ParseTime || cfg.Loc != time.UTC || cfg.Timeout != 10*time.Second || cfg.ReadTimeout != 30*time.Second {
		t.Fatal("required MySQL safety options missing")
	}
}
