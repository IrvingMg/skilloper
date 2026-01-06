package main

import (
	"go.uber.org/zap"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/database"
	"github.com/irvingmg/skilloper/skilloper-api/internal/logger"
	"github.com/irvingmg/skilloper/skilloper-api/internal/server"
)

func main() {
	log, err := logger.NewFromEnv()
	if err != nil {
		panic("Failed to initialize logger: " + err.Error())
	}
	defer log.Sync()

	cfg := config.Load()
	log.Info("Configuration loaded",
		zap.String("port", cfg.Port),
		zap.String("database_path", cfg.DatabasePath),
	)

	db, err := database.New(cfg, log)
	if err != nil {
		log.Fatal("Failed to initialize database", zap.Error(err))
	}

	srv := server.New(cfg, db, log)
	srv.Initialize()

	log.Info("Starting server")
	if err := srv.Start(); err != nil {
		log.Fatal("Failed to start server", zap.Error(err))
	}
}
