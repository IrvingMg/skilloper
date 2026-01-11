package server

import (
	"context"
	"embed"
	"fmt"
	"io"
	"io/fs"
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
	log        *zap.Logger
	router     *gin.Engine
	httpServer *http.Server
	embeddedFS embed.FS

	rateLimiters   *middleware.RateLimiters
	authService    *services.AuthService
	authHandler    *handlers.AuthHandler
	quizHandler    *handlers.QuizHandler
	attemptHandler *handlers.AttemptHandler
	answerHandler  *handlers.AnswerHandler
	healthHandler  *handlers.HealthHandler
}

func (s *Server) SetStaticFS(fs embed.FS) {
	s.embeddedFS = fs
}

func New(cfg *config.Config, db *gorm.DB, log *zap.Logger) *Server {
	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	if err := router.SetTrustedProxies(nil); err != nil {
		log.Fatal("Failed to set trusted proxies", zap.Error(err))
	}

	return &Server{
		config: cfg,
		db:     db,
		log:    log,
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
	if err := s.setupStaticFiles(); err != nil {
		return err
	}
	return nil
}

func (s *Server) setupMiddleware() {
	s.log.Info("Setting up middleware")

	s.router.Use(gin.Recovery())

	corsConfig := cors.Config{
		AllowOrigins:     s.config.AllowedOrigins,
		AllowMethods:     s.config.AllowedMethods,
		AllowHeaders:     s.config.AllowedHeaders,
		AllowCredentials: false, // Using Authorization headers, not cookies
	}

	s.router.Use(cors.New(corsConfig))

	s.log.Info("CORS middleware configured",
		zap.Strings("allowed_origins", s.config.AllowedOrigins),
		zap.Strings("allowed_methods", s.config.AllowedMethods),
	)
}

func (s *Server) setupRateLimiters() error {
	rateLimiters, err := middleware.NewRateLimiters(s.config.RateLimit, s.config.Redis, s.log)
	if err != nil {
		return err
	}
	s.rateLimiters = rateLimiters
	return nil
}

func (s *Server) setupServices() {
	s.log.Info("Setting up services and handlers")

	s.authService = services.NewAuthService(s.db, s.config.JWTSecret, s.config.JWTExpiry, s.config.RefreshTokenExpiry, s.log)
	quizService := services.NewQuizService(s.db)
	attemptService := services.NewAttemptService(s.db, s.log)
	answerService := services.NewAnswerService(s.db, s.log)
	healthService := services.NewHealthService()

	errHandler := handlers.NewErrorHandler(s.log)
	s.authHandler = handlers.NewAuthHandler(s.authService, errHandler, s.log)
	s.quizHandler = handlers.NewQuizHandler(quizService, errHandler, s.log)
	s.attemptHandler = handlers.NewAttemptHandler(attemptService, errHandler, s.log)
	s.answerHandler = handlers.NewAnswerHandler(answerService, errHandler, s.log)
	s.healthHandler = handlers.NewHealthHandler(healthService, s.log)
}

func (s *Server) setupRoutes() {
	s.log.Info("Setting up routes")

	api := s.router.Group("/api/v1")

	api.GET("/health", s.healthHandler.HealthCheck)
	api.POST("/users", s.rateLimiters.Register, s.authHandler.Register)
	api.POST("/sessions", s.rateLimiters.Login, s.authHandler.Login)
	api.POST("/sessions/refresh", s.rateLimiters.Login, s.authHandler.RefreshToken)

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

	s.log.Info("Routes configured successfully")
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
		s.log.Info("Server starting with TLS",
			zap.String("port", s.config.Port),
			zap.String("cert_file", s.config.TLS.CertFile),
		)
		if err := s.httpServer.ListenAndServeTLS(s.config.TLS.CertFile, s.config.TLS.KeyFile); err != nil && err != http.ErrServerClosed {
			return err
		}
	} else {
		s.log.Info("Server starting",
			zap.String("port", s.config.Port),
			zap.String("health_check", "/api/v1/health"),
		)
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			return err
		}
	}
	return nil
}

func (s *Server) setupStaticFiles() error {
	switch s.config.StaticMode {
	case config.StaticModeNone:
		s.log.Info("Static file serving disabled")
		return nil
	case config.StaticModeDir:
		return s.setupDirStaticFiles()
	case config.StaticModeEmbed:
		return s.setupEmbedStaticFiles()
	default:
		return fmt.Errorf("unknown STATIC_MODE: %s", s.config.StaticMode)
	}
}

func (s *Server) setupEmbedStaticFiles() error {
	staticFS, err := fs.Sub(s.embeddedFS, "static")
	if err != nil {
		return fmt.Errorf("no embedded static files (use STATIC_MODE=none for API-only or build with 'make build'): %w", err)
	}

	if _, err := staticFS.Open("index.html"); err != nil {
		return fmt.Errorf("no index.html in embedded files (use STATIC_MODE=none for API-only or build with 'make build')")
	}

	s.log.Info("Serving embedded static files")
	s.router.NoRoute(s.embeddedFileHandler(staticFS))
	return nil
}

func (s *Server) setupDirStaticFiles() error {
	absStaticDir, err := filepath.Abs(s.config.StaticDir)
	if err != nil {
		return fmt.Errorf("failed to resolve static directory path: %w", err)
	}

	if _, err := os.Stat(absStaticDir); os.IsNotExist(err) {
		return fmt.Errorf("static directory not found: %s", absStaticDir)
	}

	if _, err := os.Stat(filepath.Join(absStaticDir, "index.html")); err != nil {
		return fmt.Errorf("no index.html in static directory: %s", absStaticDir)
	}

	s.log.Info("Serving static files from directory", zap.String("path", absStaticDir))
	s.router.NoRoute(s.dirFileHandler(absStaticDir))
	return nil
}

func (s *Server) embeddedFileHandler(staticFS fs.FS) gin.HandlerFunc {
	httpFS := http.FS(staticFS)

	serveFile := func(c *gin.Context, name string) {
		file, err := httpFS.Open(name)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}
		defer func() {
			if err := file.Close(); err != nil {
				s.log.Warn("Failed to close embedded file", zap.Error(err))
			}
		}()

		stat, err := file.Stat()
		if err != nil || stat.IsDir() {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}

		http.ServeContent(c.Writer, c.Request, name, stat.ModTime(), file.(io.ReadSeeker))
	}

	return func(c *gin.Context) {
		path := c.Request.URL.Path

		if strings.HasPrefix(path, "/api/") {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}

		cleanPath := strings.TrimPrefix(path, "/")
		if cleanPath == "" {
			cleanPath = "index.html"
		}

		if file, err := staticFS.Open(cleanPath); err == nil {
			if closeErr := file.Close(); closeErr != nil {
				s.log.Warn("Failed to close static file", zap.Error(closeErr))
			}
			s.setCacheHeaders(c, path)
			serveFile(c, cleanPath)
			return
		}

		if !strings.Contains(filepath.Base(path), ".") {
			c.Header("Cache-Control", "no-cache, no-store, must-revalidate")
			serveFile(c, "index.html")
			return
		}

		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
	}
}

func (s *Server) dirFileHandler(absStaticDir string) gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path

		if strings.HasPrefix(path, "/api/") {
			c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
			return
		}

		cleanPath := strings.TrimPrefix(path, "/")
		cleanPath = filepath.Clean(cleanPath)
		filePath := filepath.Join(absStaticDir, cleanPath)

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
	s.log.Info("Shutting down server")

	ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()

	if s.httpServer != nil {
		if err := s.httpServer.Shutdown(ctx); err != nil {
			s.log.Error("HTTP server shutdown error", zap.Error(err))
		}
	}

	if s.rateLimiters != nil {
		s.rateLimiters.Close()
	}

	s.log.Info("Server shutdown complete")
}
