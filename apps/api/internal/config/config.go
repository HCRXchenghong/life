package config

import (
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

type Config struct {
	Address           string
	PublicOrigin      string
	MySQLDSN          string
	AuthMasterKey     []byte
	AIMasterKey       []byte
	AdminSetupToken   string
	AssetDirectory    string
	AutoMigrate       bool
	ShutdownTimeout   time.Duration
	UpstreamTimeout   time.Duration
	TrustedProxyCIDRs []string
}

func Load() (Config, error) {
	authKey, err := requiredKey("AUTH_SECRET_MASTER_KEY")
	if err != nil {
		return Config{}, err
	}
	aiKey, err := requiredKey("AI_SECRET_MASTER_KEY")
	if err != nil {
		return Config{}, err
	}
	if subtle.ConstantTimeCompare(authKey, aiKey) == 1 {
		return Config{}, errors.New("AUTH_SECRET_MASTER_KEY and AI_SECRET_MASTER_KEY must be independent")
	}
	dsn, err := mysqlDSN()
	if err != nil {
		return Config{}, err
	}
	origin := strings.TrimRight(strings.TrimSpace(os.Getenv("PUBLIC_ORIGIN")), "/")
	if origin == "" {
		origin = "http://localhost:8080"
	}
	parsedOrigin, err := url.Parse(origin)
	if err != nil || parsedOrigin.Hostname() == "" || parsedOrigin.User != nil || parsedOrigin.RawQuery != "" ||
		parsedOrigin.Fragment != "" || (parsedOrigin.Path != "" && parsedOrigin.Path != "/") {
		return Config{}, errors.New("PUBLIC_ORIGIN must be an origin without credentials, path, query, or fragment")
	}
	loopback := parsedOrigin.Hostname() == "localhost"
	if ip := net.ParseIP(parsedOrigin.Hostname()); ip != nil {
		loopback = ip.IsLoopback()
	}
	if parsedOrigin.Scheme != "https" && !(parsedOrigin.Scheme == "http" && loopback) {
		return Config{}, errors.New("PUBLIC_ORIGIN must use HTTPS outside loopback development")
	}
	setupToken := os.Getenv("ADMIN_SETUP_TOKEN")
	if !loopback && (len(setupToken) < 24 || len(setupToken) > 256) {
		return Config{}, errors.New("ADMIN_SETUP_TOKEN must be 24-256 characters for non-loopback deployments")
	}
	return Config{
		Address:           envOr("HTTP_ADDR", ":8080"),
		PublicOrigin:      origin,
		MySQLDSN:          dsn,
		AuthMasterKey:     authKey,
		AIMasterKey:       aiKey,
		AdminSetupToken:   setupToken,
		AssetDirectory:    envOr("ASSET_DIRECTORY", "/var/lib/daylink/assets"),
		AutoMigrate:       boolEnv("AUTO_MIGRATE", true),
		ShutdownTimeout:   durationEnv("SHUTDOWN_TIMEOUT", 15*time.Second),
		UpstreamTimeout:   durationEnv("AI_UPSTREAM_TIMEOUT", 120*time.Second),
		TrustedProxyCIDRs: splitCSV(os.Getenv("TRUSTED_PROXY_CIDRS")),
	}, nil
}

func mysqlDSN() (string, error) {
	if raw := strings.TrimSpace(os.Getenv("MYSQL_DSN")); raw != "" {
		return raw, nil
	}
	password := os.Getenv("MYSQL_PASSWORD")
	if password == "" {
		return "", errors.New("MYSQL_DSN or MYSQL_PASSWORD is required")
	}
	cfg := mysql.NewConfig()
	cfg.User = envOr("MYSQL_USER", "daylink")
	cfg.Passwd = password
	cfg.Net = "tcp"
	cfg.Addr = net.JoinHostPort(envOr("MYSQL_HOST", "127.0.0.1"), envOr("MYSQL_PORT", "3306"))
	cfg.DBName = envOr("MYSQL_DATABASE", "daylink")
	return cfg.FormatDSN(), nil
}

func requiredKey(name string) ([]byte, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	decoded, err := base64.StdEncoding.DecodeString(raw)
	if err != nil || len(decoded) != 32 {
		return nil, fmt.Errorf("%s must be a Base64-encoded 32-byte key", name)
	}
	return decoded, nil
}

func envOr(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func boolEnv(name string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	return err == nil && parsed
}

func durationEnv(name string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func splitCSV(value string) []string {
	var result []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			result = append(result, item)
		}
	}
	return result
}
