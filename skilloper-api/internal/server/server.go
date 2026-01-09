package server

import (
	"context"
	"net/http"
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
