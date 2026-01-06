package logger

import (
	"os"

	"go.uber.org/zap"
)

type Config struct {
	Level       string // debug, info, warn, error
	Environment string // development, production
}

// New creates a new structured logger based on the environment
func New(config Config) (*zap.Logger, error) {
	var zapConfig zap.Config

	switch config.Environment {
	case "production":
		zapConfig = zap.NewProductionConfig()
	default:
		zapConfig = zap.NewDevelopmentConfig()
	}

	level, err := zap.ParseAtomicLevel(config.Level)
	if err != nil {
		level = zap.NewAtomicLevelAt(zap.InfoLevel)
	}
	zapConfig.Level = level

	logger, err := zapConfig.Build()
	if err != nil {
		return nil, err
	}

	return logger, nil
}

// NewFromEnv creates a logger using environment variables
func NewFromEnv() (*zap.Logger, error) {
	config := Config{
		Level:       getEnv("LOG_LEVEL", "info"),
		Environment: getEnv("ENVIRONMENT", "development"),
	}

	return New(config)
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
