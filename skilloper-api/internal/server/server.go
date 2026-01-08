package server

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/handlers"
	"github.com/irvingmg/skilloper/skilloper-api/internal/middleware"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type Server struct {
	config *config.Config
	db     *gorm.DB
	logger *zap.Logger
	router *gin.Engine

	authService    *services.AuthService
	authHandler    *handlers.AuthHandler
	quizHandler    *handlers.QuizHandler
	attemptHandler *handlers.AttemptHandler
	answerHandler  *handlers.AnswerHandler
	healthHandler  *handlers.HealthHandler
}

func New(cfg *config.Config, db *gorm.DB, logger *zap.Logger) *Server {
	return &Server{
		config: cfg,
		db:     db,
		logger: logger,
		router: gin.Default(),
	}
}

func (s *Server) Initialize() {
	s.setupMiddleware()
	s.setupServices()
	s.setupRoutes()
}

func (s *Server) setupMiddleware() {
	s.logger.Info("Setting up middleware")

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
	api.POST("/users", s.authHandler.Register)
	api.POST("/sessions", s.authHandler.Login)

	// All other routes require authentication
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware(s.authService))
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
	s.logger.Info("Server starting",
		zap.String("port", s.config.Port),
		zap.String("health_check_url", "http://localhost:"+s.config.Port+"/api/v1/health"),
	)

	return s.router.Run(":" + s.config.Port)
}
