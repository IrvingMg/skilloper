package server

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/handlers"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

const (
	shutdownTimeout   = 5 * time.Second
	readHeaderTimeout = 5 * time.Second
	readTimeout       = 30 * time.Second
	writeTimeout      = 30 * time.Second
	idleTimeout       = 120 * time.Second
)

type Server struct {
	config     *config.Config
	db         *gorm.DB
	logger     *zap.Logger
	router     *gin.Engine
	httpServer *http.Server

	rateLimiters   *middleware.RateLimiters
	authService    *services.AuthService
	authHandler    *handlers.AuthHandler
	quizHandler    *handlers.QuizHandler
	attemptHandler *handlers.AttemptHandler
	answerHandler  *handlers.AnswerHandler
	healthHandler  *handlers.HealthHandler
}

func New(cfg *config.Config, db *gorm.DB, logger *zap.Logger) *Server {
	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	if err := router.SetTrustedProxies(nil); err != nil {
		logger.Fatal("Failed to set trusted proxies", zap.Error(err))
	}

	return &Server{
		config: cfg,
		db:     db,
		logger: logger,
		router: router,
	}
}

func (s *Server) Initialize() error {
	s.setupMiddleware()
	if err := s.setupRateLimiters(); err != nil {
		return err
	}
	s.setupServices()
	s.setupRoutes()
	s.setupStaticFiles()
	return nil
}

func (s *Server) setupMiddleware() {
	s.logger.Info("Setting up middleware")

	s.router.Use(gin.Recovery())

	corsConfig := cors.Config{
		AllowOrigins:     s.config.AllowedOrigins,
		AllowMethods:     s.config.AllowedMethods,
		AllowHeaders:     s.config.AllowedHeaders,
		AllowCredentials: false, // Using Authorization headers, not cookies
	}

	s.router.Use(cors.New(corsConfig))

	s.logger.Info("CORS middleware configured",
		zap.Strings("allowed_origins", s.config.AllowedOrigins),
		zap.Strings("allowed_methods", s.config.AllowedMethods),
	)
}

func (s *Server) setupRateLimiters() error {
	rateLimiters, err := middleware.NewRateLimiters(s.config.RateLimit, s.config.Redis, s.logger)
	if err != nil {
		return err
	}
	s.rateLimiters = rateLimiters
	return nil
}

func (s *Server) setupServices() {
	s.logger.Info("Setting up services and handlers")

	s.authService = services.NewAuthService(s.db, s.config.JWTSecret, s.config.JWTExpiry, s.logger)
	quizService := services.NewQuizService(s.db)
	attemptService := services.NewAttemptService(s.db, s.logger)
	answerService := services.NewAnswerService(s.db, s.logger)
	healthService := services.NewHealthService()

	s.authHandler = handlers.NewAuthHandler(s.authService, s.logger)
	s.quizHandler = handlers.NewQuizHandler(quizService, s.logger)
	s.attemptHandler = handlers.NewAttemptHandler(attemptService, s.logger)
	s.answerHandler = handlers.NewAnswerHandler(answerService, s.logger)
	s.healthHandler = handlers.NewHealthHandler(healthService, s.logger)
}

func (s *Server) setupRoutes() {
	s.logger.Info("Setting up routes")

	api := s.router.Group("/api/v1")

	api.GET("/health", s.healthHandler.HealthCheck)
	api.POST("/users", s.rateLimiters.Register, s.authHandler.Register)
	api.POST("/sessions", s.rateLimiters.Login, s.authHandler.Login)

	// All other routes require authentication
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware(s.authService))
	protected.Use(s.rateLimiters.API)
	{
		// Auth routes
		protected.GET("/users/me", s.authHandler.GetCurrentUser)
		protected.PUT("/users/me/password", s.authHandler.UpdatePassword)
		protected.POST("/users/me/history-clearance", s.authHandler.ResetHistory)
		protected.POST("/users/me/deletion", s.authHandler.DeleteAccount)
		protected.DELETE("/sessions", s.authHandler.Logout)

		// Quiz routes
		protected.GET("/quizzes/summaries", s.quizHandler.GetQuizSummaries)
		protected.GET("/quizzes/:id", s.quizHandler.GetQuiz)
		protected.POST("/quizzes", s.quizHandler.CreateQuiz)
		protected.PUT("/quizzes/:id", s.quizHandler.UpdateQuiz)
		protected.DELETE("/quizzes/:id", s.quizHandler.DeleteQuiz)

		// Attempt routes
		protected.POST("/attempts", s.attemptHandler.CreateAttempt)
		protected.PATCH("/attempts/:id", s.attemptHandler.UpdateAttempt)
		protected.GET("/attempts", s.attemptHandler.GetAttempts)
		protected.GET("/attempts/:id", s.attemptHandler.GetAttempt)

		// Answer routes
		protected.POST("/answers", s.answerHandler.CreateAnswer)
	}

	s.logger.Info("Routes configured successfully")
}

func (s *Server) Start() error {
	s.httpServer = &http.Server{
		Addr:              ":" + s.config.Port,
		Handler:           s.router,
		ReadHeaderTimeout: readHeaderTimeout,
		ReadTimeout:       readTimeout,
		WriteTimeout:      writeTimeout,
		IdleTimeout:       idleTimeout,
	}

	if s.config.TLS.Enabled() {
		s.logger.Info("Server starting with TLS",
			zap.String("port", s.config.Port),
			zap.String("cert_file", s.config.TLS.CertFile),
		)
		if err := s.httpServer.ListenAndServeTLS(s.config.TLS.CertFile, s.config.TLS.KeyFile); err != nil && err != http.ErrServerClosed {
			return err
		}
	} else {
		s.logger.Info("Server starting",
			zap.String("port", s.config.Port),
			zap.String("health_check", "/api/v1/health"),
		)
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			return err
		}
	}
	return nil
}

func (s *Server) setupStaticFiles() {
	if !s.config.StaticServing() {
		s.logger.Info("Static file serving disabled")
		return
	}

	staticDir := s.config.StaticDir
	absStaticDir, err := filepath.Abs(staticDir)
	if err != nil {
		s.logger.Error("Failed to resolve static directory path",
			zap.String("path", staticDir), zap.Error(err))
		return
	}

	if _, err := os.Stat(absStaticDir); os.IsNotExist(err) {
		s.logger.Warn("Static directory not found, skipping static file setup",
			zap.String("path", absStaticDir))
		return
	}

	s.logger.Info("Setting up static file serving", zap.String("directory", absStaticDir))
	s.router.NoRoute(s.staticFileHandler(absStaticDir))
}

func (s *Server) staticFileHandler(absStaticDir string) gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path

		if strings.HasPrefix(path, "/api/") {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}

		cleanPath := strings.TrimPrefix(path, "/")
		cleanPath = filepath.Clean(cleanPath)
		filePath := filepath.Join(absStaticDir, cleanPath)

		// Verify path is within static directory (catches traversal attempts)
		relPath, err := filepath.Rel(absStaticDir, filePath)
		if err != nil || strings.HasPrefix(relPath, "..") {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}

		if info, err := os.Stat(filePath); err == nil && !info.IsDir() {
			s.setCacheHeaders(c, path)
			c.File(filePath)
			return
		}

		if !strings.Contains(filepath.Base(path), ".") {
			indexPath := filepath.Join(absStaticDir, "index.html")
			c.Header("Cache-Control", "no-cache, no-store, must-revalidate")
			c.File(indexPath)
			return
		}

		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
	}
}

func (s *Server) setCacheHeaders(c *gin.Context, path string) {
	if path == "/" || path == "/index.html" {
		c.Header("Cache-Control", "no-cache, no-store, must-revalidate")
		return
	}

	ext := filepath.Ext(path)
	switch ext {
	case ".js", ".css", ".woff2", ".woff", ".ttf", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".wasm":
		c.Header("Cache-Control", "public, max-age=31536000, immutable")
	default:
		c.Header("Cache-Control", "public, max-age=3600")
	}
}

func (s *Server) Shutdown() {
	s.logger.Info("Shutting down server")

	ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()

	if s.httpServer != nil {
		if err := s.httpServer.Shutdown(ctx); err != nil {
			s.logger.Error("HTTP server shutdown error", zap.Error(err))
		}
	}

	if s.rateLimiters != nil {
		s.rateLimiters.Close()
	}

	s.logger.Info("Server shutdown complete")
}
