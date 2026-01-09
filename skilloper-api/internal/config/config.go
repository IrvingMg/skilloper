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

func init() {
	if os.Getenv("APP_ENV") == EnvDevelopment {
		godotenv.Load()
	}
}

type Config struct {
	AppEnv         string
	Port           string
	DBDriver       string
	DatabasePath   string
	DatabaseURL    string
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
	JWTSecret      string
	JWTExpiry      time.Duration
	AdminUsername  string
	AdminPassword  string
	RateLimit      RateLimitConfig
	Redis          RedisConfig
}

type RateLimitConfig struct {
	Enabled      bool
	LoginRate    string
	RegisterRate string
	APIRate      string
}

type RedisConfig struct {
	URL       string
	KeyPrefix string
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
		AppEnv:         appEnv,
		Port:           getEnv("PORT", "8080"),
		DBDriver:       dbDriver,
		DatabasePath:   getEnv("DATABASE_PATH", "skilloper.db"),
		DatabaseURL:    getEnv("DATABASE_URL", ""),
		AllowedOrigins: parseAllowedOrigins(),
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Origin", "Content-Type", "Authorization"},
		JWTSecret:      requireEnv("JWT_SECRET"),
		JWTExpiry:      parseJWTExpiry(),
		AdminUsername:  adminUsername,
		AdminPassword:  adminPassword,
		RateLimit:      parseRateLimitConfig(),
		Redis:          parseRedisConfig(),
	}

	if cfg.DBDriver != DBDriverSQLite && cfg.DBDriver != DBDriverPostgres {
		log.Fatalf("Unsupported DB_DRIVER: %s (must be 'sqlite' or 'postgres')", cfg.DBDriver)
	}
	if cfg.DBDriver == DBDriverPostgres && cfg.DatabaseURL == "" {
		log.Fatal("DATABASE_URL is required when DB_DRIVER=postgres")
	}

	return cfg
}

// parseJWTExpiry parses the JWT_EXPIRY environment variable (in hours)
func parseJWTExpiry() time.Duration {
	expiryStr := getEnv("JWT_EXPIRY", "24")
	hours, err := strconv.Atoi(expiryStr)
	if err != nil || hours <= 0 {
		hours = 24
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
		Enabled:      getEnvBool("RATE_LIMIT_ENABLED", false),
		LoginRate:    getEnv("RATE_LIMIT_LOGIN", "5-M"),
		RegisterRate: getEnv("RATE_LIMIT_REGISTER", "3-M"),
		APIRate:      getEnv("RATE_LIMIT_API", "120-M"),
	}
}

// parseRedisConfig parses Redis configuration
func parseRedisConfig() RedisConfig {
	return RedisConfig{
		URL:       getEnv("REDIS_URL", ""),
		KeyPrefix: getEnv("REDIS_KEY_PREFIX", "skilloper"),
	}
}
