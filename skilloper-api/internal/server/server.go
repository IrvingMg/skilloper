package server

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/handlers"
	"github.com/irvingmg/skilloper/skilloper-api/internal/services"
)

type Server struct {
	config *config.Config
	db     *gorm.DB
	logger *zap.Logger
	router *gin.Engine

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
		AllowCredentials: true,
	}

	s.router.Use(cors.New(corsConfig))

	s.logger.Info("CORS middleware configured",
		zap.Strings("allowed_origins", s.config.AllowedOrigins),
		zap.Strings("allowed_methods", s.config.AllowedMethods),
	)
}

func (s *Server) setupServices() {
	s.logger.Info("Setting up services and handlers")

	quizService := services.NewQuizService(s.db)
	attemptService := services.NewAttemptService(s.db, s.logger)
	answerService := services.NewAnswerService(s.db, s.logger)
	healthService := services.NewHealthService()

	s.quizHandler = handlers.NewQuizHandler(quizService, s.logger)
	s.attemptHandler = handlers.NewAttemptHandler(attemptService, s.logger)
	s.answerHandler = handlers.NewAnswerHandler(answerService, s.logger)
	s.healthHandler = handlers.NewHealthHandler(healthService, s.logger)
}

func (s *Server) setupRoutes() {
	s.logger.Info("Setting up routes")

	api := s.router.Group("/api/v1")

	api.GET("/quizzes/summaries", s.quizHandler.GetQuizSummaries)
	api.POST("/quizzes", s.quizHandler.CreateQuiz)
	api.GET("/quizzes/:id", s.quizHandler.GetQuiz)
	api.PUT("/quizzes/:id", s.quizHandler.UpdateQuiz)
	api.DELETE("/quizzes/:id", s.quizHandler.DeleteQuiz)

	api.POST("/attempts", s.attemptHandler.CreateAttempt)
	api.PATCH("/attempts/:id", s.attemptHandler.UpdateAttempt)
	api.GET("/attempts", s.attemptHandler.GetAttempts)
	api.GET("/attempts/:id", s.attemptHandler.GetAttempt)

	api.POST("/answers", s.answerHandler.CreateAnswer)

	api.GET("/health", s.healthHandler.HealthCheck)

	s.logger.Info("Routes configured successfully")
}

func (s *Server) Start() error {
	s.logger.Info("Server starting",
		zap.String("port", s.config.Port),
		zap.String("health_check_url", "http://localhost:"+s.config.Port+"/api/v1/health"),
	)

	return s.router.Run(":" + s.config.Port)
}
