package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

const (
	AuthorizationHeader = "Authorization"
	BearerPrefix        = "Bearer "
	UserIDKey           = "user_id"
	UsernameKey         = "username"
	IsAdminKey          = "is_admin"
)

func AuthMiddleware(authService *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader(AuthorizationHeader)
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Missing authorization header", "code": "UNAUTHORIZED"})
			c.Abort()
			return
		}

		if !strings.HasPrefix(authHeader, BearerPrefix) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format", "code": "UNAUTHORIZED"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, BearerPrefix)
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Missing token", "code": "UNAUTHORIZED"})
			c.Abort()
			return
		}

		claims, err := authService.ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token", "code": "INVALID_TOKEN"})
			c.Abort()
			return
		}

		c.Set(UserIDKey, claims.UserID)
		c.Set(UsernameKey, claims.Username)
		c.Set(IsAdminKey, claims.IsAdmin)

		c.Next()
	}
}

func GetUserID(c *gin.Context) uint {
	userID, exists := c.Get(UserIDKey)
	if !exists {
		return 0
	}
	id, ok := userID.(uint)
	if !ok {
		return 0
	}
	return id
}

func GetUsername(c *gin.Context) string {
	username, exists := c.Get(UsernameKey)
	if !exists {
		return ""
	}
	name, ok := username.(string)
	if !ok {
		return ""
	}
	return name
}

func IsAdmin(c *gin.Context) bool {
	isAdmin, exists := c.Get(IsAdminKey)
	if !exists {
		return false
	}
	admin, ok := isAdmin.(bool)
	if !ok {
		return false
	}
	return admin
}
