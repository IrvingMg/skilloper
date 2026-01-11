package config

import (
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

const (
	DBDriverSQLite   = "sqlite"
	DBDriverPostgres = "postgres"
)

const (
	EnvProduction  = "production"
	EnvDevelopment = "development"
)

const (
	StaticModeEmbed = "embed"
	StaticModeDir   = "dir"
	StaticModeNone  = "none"
)

const MinJWTSecretLength = 32

var DefaultStaticMode = StaticModeEmbed

func init() {
	if os.Getenv("APP_ENV") == EnvDevelopment {
		godotenv.Load()
	}
}

type Config struct {
	AppEnv             string
	Port               string
	DBDriver           string
	DatabasePath       string
	DatabaseURL        string
	DBPool             DBPoolConfig
	AllowedOrigins     []string
	AllowedMethods     []string
	AllowedHeaders     []string
	JWTSecret          string
	JWTExpiry          time.Duration
	RefreshTokenExpiry time.Duration
	AdminUsername      string
	AdminPassword      string
	RateLimit          RateLimitConfig
	Redis              RedisConfig
	TLS                TLSConfig
	StaticMode         string
	StaticDir          string
}

type DBPoolConfig struct {
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
	ConnMaxIdleTime time.Duration
}

func (c *Config) StaticServing() bool {
	return c.StaticMode != StaticModeNone
}

type RateLimitConfig struct {
	Enabled          bool
	GracefulFallback bool // If true, disable rate limiting when Redis is unavailable instead of failing
	LoginRate        string
	RegisterRate     string
	APIRate          string
}

type RedisConfig struct {
	URL       string
	KeyPrefix string
}

type TLSConfig struct {
	CertFile string
	KeyFile  string
}

func (t TLSConfig) Enabled() bool {
	return t.CertFile != "" && t.KeyFile != ""
}

// IsProduction returns true if running in production environment
func (c *Config) IsProduction() bool {
	return c.AppEnv == EnvProduction
}

// IsDevelopment returns true if running in development environment
func (c *Config) IsDevelopment() bool {
	return c.AppEnv == EnvDevelopment
}

// Load loads configuration from environment variables with defaults
func Load() *Config {
	appEnv := getEnv("APP_ENV", "")
	dbDriver := normalizeDBDriver(getEnv("DB_DRIVER", DBDriverSQLite))

	// Admin credentials: always required (use .env file in development)
	adminUsername := requireEnv("ADMIN_USERNAME")
	adminPassword := requireEnv("ADMIN_PASSWORD")

	cfg := &Config{
		AppEnv:             appEnv,
		Port:               getEnv("PORT", "8080"),
		DBDriver:           dbDriver,
		DatabasePath:       getEnv("DATABASE_PATH", "skilloper.db"),
		DatabaseURL:        getEnv("DATABASE_URL", ""),
		DBPool:             parseDBPoolConfig(),
		AllowedOrigins:     parseAllowedOrigins(),
		AllowedMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		JWTSecret:          requireEnv("JWT_SECRET"),
		JWTExpiry:          parseJWTExpiry(),
		RefreshTokenExpiry: parseRefreshTokenExpiry(),
		AdminUsername:      adminUsername,
		AdminPassword:      adminPassword,
		RateLimit:          parseRateLimitConfig(),
		Redis:              parseRedisConfig(),
		TLS:                parseTLSConfig(),
		StaticMode:         getEnv("STATIC_MODE", DefaultStaticMode),
		StaticDir:          getEnv("STATIC_DIR", ""),
	}

	if cfg.DBDriver != DBDriverSQLite && cfg.DBDriver != DBDriverPostgres {
		log.Fatalf("Unsupported DB_DRIVER: %s (must be 'sqlite' or 'postgres')", cfg.DBDriver)
	}
	if cfg.DBDriver == DBDriverPostgres && cfg.DatabaseURL == "" {
		log.Fatal("DATABASE_URL is required when DB_DRIVER=postgres")
	}
	if cfg.StaticMode != StaticModeEmbed && cfg.StaticMode != StaticModeDir && cfg.StaticMode != StaticModeNone {
		log.Fatalf("Invalid STATIC_MODE: %s (must be 'embed', 'dir', or 'none')", cfg.StaticMode)
	}
	if cfg.StaticMode == StaticModeDir && cfg.StaticDir == "" {
		log.Fatal("STATIC_DIR is required when STATIC_MODE=dir")
	}
	if len(cfg.JWTSecret) < MinJWTSecretLength {
		log.Fatalf("JWT_SECRET must be at least %d characters long for security", MinJWTSecretLength)
	}

	if cfg.IsProduction() {
		for _, origin := range cfg.AllowedOrigins {
			if origin == "*" {
				log.Fatal("Wildcard CORS origin (*) is not allowed in production")
			}
		}
	}

	return cfg
}

// parseJWTExpiry parses the JWT_EXPIRY environment variable (in hours)
func parseJWTExpiry() time.Duration {
	expiryStr := getEnv("JWT_EXPIRY", "1")
	hours, err := strconv.Atoi(expiryStr)
	if err != nil || hours <= 0 {
		hours = 1
	}
	return time.Duration(hours) * time.Hour
}

// parseRefreshTokenExpiry parses the REFRESH_TOKEN_EXPIRY environment variable (in hours)
func parseRefreshTokenExpiry() time.Duration {
	expiryStr := getEnv("REFRESH_TOKEN_EXPIRY", "168") // 168 hours = 7 days
	hours, err := strconv.Atoi(expiryStr)
	if err != nil || hours <= 0 {
		hours = 168
	}
	return time.Duration(hours) * time.Hour
}

// parseAllowedOrigins parses the ALLOWED_ORIGINS environment variable
func parseAllowedOrigins() []string {
	originsStr := getEnv("ALLOWED_ORIGINS", "")

	if originsStr == "" {
		return []string{
			"http://localhost:3000",
			"http://localhost:3001",
			"http://127.0.0.1:3000",
			"http://127.0.0.1:3001",
		}
	}

	origins := strings.Split(originsStr, ",")
	for i, origin := range origins {
		origins[i] = strings.TrimSpace(origin)
	}

	return origins
}

// normalizeDBDriver normalizes database driver name to handle case and aliases
func normalizeDBDriver(driver string) string {
	switch strings.ToLower(driver) {
	case "postgres", "postgresql":
		return DBDriverPostgres
	case "sqlite", "sqlite3":
		return DBDriverSQLite
	default:
		return strings.ToLower(driver)
	}
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// requireEnv gets an environment variable or exits if not set
func requireEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("Required environment variable %s is not set", key)
	}
	return value
}

// getEnvBool gets an environment variable as boolean
func getEnvBool(key string, defaultValue bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return strings.ToLower(value) == "true" || value == "1"
}

// parseRateLimitConfig parses rate limiting configuration
func parseRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		Enabled:          getEnvBool("RATE_LIMIT_ENABLED", false),
		GracefulFallback: getEnvBool("RATE_LIMIT_GRACEFUL_FALLBACK", true),
		LoginRate:        getEnv("RATE_LIMIT_LOGIN", "5-M"),
		RegisterRate:     getEnv("RATE_LIMIT_REGISTER", "3-M"),
		APIRate:          getEnv("RATE_LIMIT_API", "120-M"),
	}
}

// parseRedisConfig parses Redis configuration
func parseRedisConfig() RedisConfig {
	return RedisConfig{
		URL:       getEnv("REDIS_URL", ""),
		KeyPrefix: getEnv("REDIS_KEY_PREFIX", "skilloper"),
	}
}

// parseDBPoolConfig parses database connection pool configuration
func parseDBPoolConfig() DBPoolConfig {
	maxOpenConns := getEnvInt("DB_MAX_OPEN_CONNS", 25)
	maxIdleConns := getEnvInt("DB_MAX_IDLE_CONNS", 10)
	connMaxLifetimeMins := getEnvInt("DB_CONN_MAX_LIFETIME_MINS", 30)
	connMaxIdleTimeMins := getEnvInt("DB_CONN_MAX_IDLE_TIME_MINS", 5)

	return DBPoolConfig{
		MaxOpenConns:    maxOpenConns,
		MaxIdleConns:    maxIdleConns,
		ConnMaxLifetime: time.Duration(connMaxLifetimeMins) * time.Minute,
		ConnMaxIdleTime: time.Duration(connMaxIdleTimeMins) * time.Minute,
	}
}

// getEnvInt gets an environment variable as a non-negative integer with a default value
func getEnvInt(key string, defaultValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	intVal, err := strconv.Atoi(value)
	if err != nil || intVal < 0 {
		return defaultValue
	}
	return intVal
}

// parseTLSConfig parses TLS configuration
func parseTLSConfig() TLSConfig {
	certFile := getEnv("TLS_CERT_FILE", "")
	keyFile := getEnv("TLS_KEY_FILE", "")

	if (certFile != "" && keyFile == "") || (certFile == "" && keyFile != "") {
		log.Fatal("Both TLS_CERT_FILE and TLS_KEY_FILE must be set together, or neither")
	}

	if certFile != "" && keyFile != "" {
		if _, err := os.Stat(certFile); os.IsNotExist(err) {
			log.Fatalf("TLS certificate file not found: %s", certFile)
		}
		if _, err := os.Stat(keyFile); os.IsNotExist(err) {
			log.Fatalf("TLS key file not found: %s", keyFile)
		}
	}

	return TLSConfig{
		CertFile: certFile,
		KeyFile:  keyFile,
	}
}
