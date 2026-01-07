package services

import (
	"time"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

const (
	HealthStatusOK      = "ok"
	HealthStatusMessage = "Skilloper API is running"
)

type HealthService struct{}

func NewHealthService() *HealthService {
	return &HealthService{}
}

func (s *HealthService) GetHealth() models.HealthResponse {
	return models.HealthResponse{
		Status:    HealthStatusOK,
		Message:   HealthStatusMessage,
		Timestamp: time.Now().Format(time.RFC3339),
	}
}
