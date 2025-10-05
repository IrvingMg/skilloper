package services

import (
	"time"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type HealthService struct{}

func NewHealthService() *HealthService {
	return &HealthService{}
}

// GetHealth returns the health status of the API
func (s *HealthService) GetHealth() models.HealthResponse {
	return models.HealthResponse{
		Status:    "ok",
		Message:   "Skilloper API is running",
		Timestamp: time.Now().Format(time.RFC3339),
	}
}
