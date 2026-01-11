package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type HealthHandler struct {
	service *services.HealthService
	log     *zap.Logger
}

func NewHealthHandler(service *services.HealthService, log *zap.Logger) *HealthHandler {
	return &HealthHandler{
		service: service,
		log:     log,
	}
}

// HealthCheck handles GET /health
func (h *HealthHandler) HealthCheck(c *gin.Context) {
	h.log.Debug("Health check requested")

	response := h.service.GetHealth()

	h.log.Debug("Health check completed",
		zap.String("status", response.Status),
	)

	c.JSON(http.StatusOK, response)
}
