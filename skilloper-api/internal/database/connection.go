package database

import (
	"go.uber.org/zap"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// New creates a new database connection and runs migrations
func New(cfg *config.Config, logger *zap.Logger) (*gorm.DB, error) {
	logger.Info("Connecting to database", zap.String("path", cfg.DatabasePath))

	db, err := gorm.Open(sqlite.Open(cfg.DatabasePath), &gorm.Config{})
	if err != nil {
		logger.Error("Failed to connect to database", zap.Error(err))
		return nil, err
	}

	logger.Info("Running database migrations")
	// Auto-migrate models
	err = db.AutoMigrate(
		&models.Questionnaire{},
		&models.Question{},
		&models.QuizAttempt{},
		&models.AttemptAnswer{},
	)
	if err != nil {
		logger.Error("Failed to migrate database", zap.Error(err))
		return nil, err
	}

	// Seed sample data if database is empty
	var count int64
	db.Model(&models.Questionnaire{}).Count(&count)
	if count == 0 {
		logger.Info("Database is empty, seeding sample data")
		if err := seedSampleData(db, logger); err != nil {
			logger.Error("Failed to seed sample data", zap.Error(err))
			return nil, err
		}
	} else {
		logger.Info("Database already contains data, skipping seed", zap.Int64("questionnaire_count", count))
	}

	logger.Info("Database initialized successfully")
	return db, nil
}
