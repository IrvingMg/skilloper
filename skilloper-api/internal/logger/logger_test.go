package logger

import (
	"testing"

	"go.uber.org/zap/zapcore"
)

func TestNew_ValidLevels(t *testing.T) {
	tests := []struct {
		level    string
		expected zapcore.Level
	}{
		{"debug", zapcore.DebugLevel},
		{"info", zapcore.InfoLevel},
		{"warn", zapcore.WarnLevel},
		{"error", zapcore.ErrorLevel},
	}

	for _, tt := range tests {
		t.Run(tt.level, func(t *testing.T) {
			logger, err := New(Config{Level: tt.level, Environment: "development"})
			if err != nil {
				t.Fatalf("New() error = %v", err)
			}
			defer logger.Sync()

			if !logger.Core().Enabled(tt.expected) {
				t.Errorf("logger should be enabled at %s level", tt.level)
			}
		})
	}
}

func TestNew_InvalidLevelFallsBackToInfo(t *testing.T) {
	logger, err := New(Config{Level: "invalid_level", Environment: "development"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	defer logger.Sync()

	if !logger.Core().Enabled(zapcore.InfoLevel) {
		t.Error("logger should be enabled at info level for invalid level input")
	}
	if logger.Core().Enabled(zapcore.DebugLevel) {
		t.Error("logger should not be enabled at debug level when defaulting to info")
	}
}

func TestNew_EmptyLevelFallsBackToInfo(t *testing.T) {
	logger, err := New(Config{Level: "", Environment: "development"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	defer logger.Sync()

	if !logger.Core().Enabled(zapcore.InfoLevel) {
		t.Error("logger should be enabled at info level for empty level")
	}
}

func TestNew_ProductionEnvironment(t *testing.T) {
	logger, err := New(Config{Level: "info", Environment: "production"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	defer logger.Sync()

	if logger == nil {
		t.Error("expected non-nil logger for production environment")
	}
}

func TestNew_DevelopmentEnvironment(t *testing.T) {
	logger, err := New(Config{Level: "info", Environment: "development"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	defer logger.Sync()

	if logger == nil {
		t.Error("expected non-nil logger for development environment")
	}
}

func TestNew_UnknownEnvironmentDefaultsToDevelopment(t *testing.T) {
	logger, err := New(Config{Level: "info", Environment: "unknown"})
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	defer logger.Sync()

	if logger == nil {
		t.Error("expected non-nil logger for unknown environment")
	}
}

func TestGetEnv_ReturnsEnvValue(t *testing.T) {
	const testKey = "TEST_LOGGER_ENV_VAR"
	const testValue = "test_value"

	t.Setenv(testKey, testValue)

	got := getEnv(testKey, "default")
	if got != testValue {
		t.Errorf("getEnv() = %q, want %q", got, testValue)
	}
}

func TestGetEnv_ReturnsDefaultWhenNotSet(t *testing.T) {
	const testKey = "TEST_LOGGER_UNSET_VAR"
	// Don't set the env var - rely on it not existing

	got := getEnv(testKey, "default_value")
	if got != "default_value" {
		t.Errorf("getEnv() = %q, want %q", got, "default_value")
	}
}

func TestGetEnv_ReturnsDefaultForEmptyValue(t *testing.T) {
	const testKey = "TEST_LOGGER_EMPTY_VAR"

	t.Setenv(testKey, "")

	got := getEnv(testKey, "default")
	if got != "default" {
		t.Errorf("getEnv() = %q, want %q for empty env var", got, "default")
	}
}
