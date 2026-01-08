package config

import (
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port           string
	DatabasePath   string
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
	JWTSecret      string
	JWTExpiry      time.Duration
}

// Load loads configuration from environment variables with defaults
func Load() *Config {
	return &Config{
		Port:           getEnv("PORT", "8080"),
		DatabasePath:   getEnv("DATABASE_PATH", "skilloper.db"),
		AllowedOrigins: parseAllowedOrigins(),
		AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Origin", "Content-Type", "Authorization"},
		JWTSecret:      requireEnv("JWT_SECRET"),
		JWTExpiry:      parseJWTExpiry(),
	}
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
