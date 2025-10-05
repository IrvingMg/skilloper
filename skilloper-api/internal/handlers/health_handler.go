package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type HealthHandler struct {
	service *services.HealthService
	logger  *zap.Logger
}

func NewHealthHandler(service *services.HealthService, logger *zap.Logger) *HealthHandler {
	return &HealthHandler{
		service: service,
		logger:  logger,
	}
}

// HealthCheck handles GET /health
func (h *HealthHandler) HealthCheck(c *gin.Context) {
	h.logger.Info("Health check requested")

	response := h.service.GetHealth()

	h.logger.Info("Health check completed",
		zap.String("status", response.Status),
	)

	c.JSON(http.StatusOK, response)
}
