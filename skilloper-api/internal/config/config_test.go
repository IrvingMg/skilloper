package config

import (
	"testing"
	"time"
)

func TestParseJWTExpiry(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		want     time.Duration
	}{
		{"default when empty", "", 24 * time.Hour},
		{"valid hours", "48", 48 * time.Hour},
		{"single hour", "1", 1 * time.Hour},
		{"invalid string", "invalid", 24 * time.Hour},
		{"zero fallback", "0", 24 * time.Hour},
		{"negative fallback", "-5", 24 * time.Hour},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("JWT_EXPIRY", tt.envValue)

			got := parseJWTExpiry()
			if got != tt.want {
				t.Errorf("parseJWTExpiry() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestParseAllowedOrigins(t *testing.T) {
	tests := []struct {
		name     string
		envValue string
		want     []string
	}{
		{
			name:     "default when empty",
			envValue: "",
			want: []string{
				"http://localhost:3000",
				"http://localhost:3001",
				"http://127.0.0.1:3000",
				"http://127.0.0.1:3001",
			},
		},
		{
			name:     "single origin",
			envValue: "https://example.com",
			want:     []string{"https://example.com"},
		},
		{
			name:     "multiple origins",
			envValue: "https://a.com,https://b.com,https://c.com",
			want:     []string{"https://a.com", "https://b.com", "https://c.com"},
		},
		{
			name:     "trims whitespace",
			envValue: " https://a.com , https://b.com ",
			want:     []string{"https://a.com", "https://b.com"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("ALLOWED_ORIGINS", tt.envValue)

			got := parseAllowedOrigins()
			if len(got) != len(tt.want) {
				t.Errorf("parseAllowedOrigins() len = %d, want %d", len(got), len(tt.want))
				return
			}
			for i, origin := range got {
				if origin != tt.want[i] {
					t.Errorf("parseAllowedOrigins()[%d] = %q, want %q", i, origin, tt.want[i])
				}
			}
		})
	}
}

func TestNormalizeDBDriver(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"sqlite", DBDriverSQLite},
		{"SQLITE", DBDriverSQLite},
		{"SQLite", DBDriverSQLite},
		{"sqlite3", DBDriverSQLite},
		{"SQLITE3", DBDriverSQLite},
		{"postgres", DBDriverPostgres},
		{"POSTGRES", DBDriverPostgres},
		{"postgresql", DBDriverPostgres},
		{"PostgreSQL", DBDriverPostgres},
		{"unknown", "unknown"},
		{"MYSQL", "mysql"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := normalizeDBDriver(tt.input)
			if got != tt.want {
				t.Errorf("normalizeDBDriver(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestGetEnvBool(t *testing.T) {
	tests := []struct {
		name         string
		envValue     string
		envSet       bool
		defaultValue bool
		want         bool
	}{
		{"true string", "true", true, false, true},
		{"TRUE string", "TRUE", true, false, true},
		{"True mixed case", "True", true, false, true},
		{"1 string", "1", true, false, true},
		{"false string", "false", true, true, false},
		{"0 string", "0", true, true, false},
		{"empty with default true", "", true, true, true},
		{"not set with default false", "", false, false, false},
		{"not set with default true", "", false, true, true},
		{"random string is false", "yes", true, true, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envSet {
				t.Setenv("TEST_BOOL", tt.envValue)
			}
			// When envSet is false, rely on env var not being set.
			// t.Setenv restores state after each subtest, so this works correctly.

			got := getEnvBool("TEST_BOOL", tt.defaultValue)
			if got != tt.want {
				t.Errorf("getEnvBool() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestTLSConfig_Enabled(t *testing.T) {
	tests := []struct {
		name     string
		certFile string
		keyFile  string
		want     bool
	}{
		{"both set", "/path/to/cert.pem", "/path/to/key.pem", true},
		{"cert only", "/path/to/cert.pem", "", false},
		{"key only", "", "/path/to/key.pem", false},
		{"neither set", "", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tls := TLSConfig{
				CertFile: tt.certFile,
				KeyFile:  tt.keyFile,
			}
			if got := tls.Enabled(); got != tt.want {
				t.Errorf("TLSConfig.Enabled() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGetEnv(t *testing.T) {
	tests := []struct {
		name         string
		envValue     string
		envSet       bool
		defaultValue string
		want         string
	}{
		{"returns env value", "custom", true, "default", "custom"},
		{"returns default when not set", "", false, "default", "default"},
		{"returns default when empty", "", true, "default", "default"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envSet {
				t.Setenv("TEST_VAR", tt.envValue)
			}

			got := getEnv("TEST_VAR", tt.defaultValue)
			if got != tt.want {
				t.Errorf("getEnv() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestConfig_IsProduction(t *testing.T) {
	tests := []struct {
		appEnv string
		want   bool
	}{
		{EnvProduction, true},
		{EnvDevelopment, false},
		{"", false},
		{"staging", false},
	}

	for _, tt := range tests {
		t.Run(tt.appEnv, func(t *testing.T) {
			cfg := &Config{AppEnv: tt.appEnv}
			if got := cfg.IsProduction(); got != tt.want {
				t.Errorf("IsProduction() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestConfig_IsDevelopment(t *testing.T) {
	tests := []struct {
		appEnv string
		want   bool
	}{
		{EnvDevelopment, true},
		{EnvProduction, false},
		{"", false},
		{"staging", false},
	}

	for _, tt := range tests {
		t.Run(tt.appEnv, func(t *testing.T) {
			cfg := &Config{AppEnv: tt.appEnv}
			if got := cfg.IsDevelopment(); got != tt.want {
				t.Errorf("IsDevelopment() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestConfig_StaticServing(t *testing.T) {
	tests := []struct {
		staticMode string
		want       bool
	}{
		{StaticModeEmbed, true},
		{StaticModeDir, true},
		{StaticModeNone, false},
	}

	for _, tt := range tests {
		t.Run(tt.staticMode, func(t *testing.T) {
			cfg := &Config{StaticMode: tt.staticMode}
			if got := cfg.StaticServing(); got != tt.want {
				t.Errorf("StaticServing() = %v, want %v", got, tt.want)
			}
		})
	}
}
