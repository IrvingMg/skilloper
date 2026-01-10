package services

import (
	"testing"
	"time"
)

func TestHealthService_GetHealth_ReturnsCorrectStatus(t *testing.T) {
	service := NewHealthService()
	health := service.GetHealth()

	if health.Status != HealthStatusOK {
		t.Errorf("Status = %q, want %q", health.Status, HealthStatusOK)
	}
}

func TestHealthService_GetHealth_ReturnsCorrectMessage(t *testing.T) {
	service := NewHealthService()
	health := service.GetHealth()

	if health.Message != HealthStatusMessage {
		t.Errorf("Message = %q, want %q", health.Message, HealthStatusMessage)
	}
}

func TestHealthService_GetHealth_ReturnsValidRFC3339Timestamp(t *testing.T) {
	service := NewHealthService()
	before := time.Now().Add(-time.Second)
	health := service.GetHealth()
	after := time.Now().Add(time.Second)

	parsed, err := time.Parse(time.RFC3339, health.Timestamp)
	if err != nil {
		t.Fatalf("Timestamp %q is not valid RFC3339: %v", health.Timestamp, err)
	}

	if parsed.Before(before) || parsed.After(after) {
		t.Errorf("Timestamp %v not within expected range [%v, %v]", parsed, before, after)
	}
}

func TestNewHealthService_ReturnsNonNil(t *testing.T) {
	service := NewHealthService()
	if service == nil {
		t.Error("NewHealthService() returned nil")
	}
}
