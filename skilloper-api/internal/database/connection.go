package database

import (
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

func openConnection(cfg *config.Config, log *zap.Logger) (*gorm.DB, error) {
	var dialector gorm.Dialector

	switch cfg.DBDriver {
	case config.DBDriverPostgres:
		log.Info("Connecting to PostgreSQL database")
		dialector = postgres.Open(cfg.DatabaseURL)
	case config.DBDriverSQLite:
		log.Info("Connecting to SQLite database", zap.String("path", cfg.DatabasePath))
		dialector = sqlite.Open(cfg.DatabasePath + "?_foreign_keys=on")
	default:
		return nil, fmt.Errorf("unsupported database driver: %s", cfg.DBDriver)
	}

	gormLogLevel := gormlogger.Silent
	if cfg.IsDevelopment() {
		gormLogLevel = gormlogger.Info
	}

	db, err := gorm.Open(dialector, &gorm.Config{
		Logger: gormlogger.Default.LogMode(gormLogLevel),
	})
	if err != nil {
		log.Error("Failed to connect to database", zap.Error(err))
		return nil, err
	}

	if cfg.DBDriver == config.DBDriverPostgres {
		sqlDB, err := db.DB()
		if err != nil {
			log.Error("Failed to get underlying DB connection", zap.Error(err))
			return nil, err
		}
		sqlDB.SetMaxOpenConns(cfg.DBPool.MaxOpenConns)
		sqlDB.SetMaxIdleConns(cfg.DBPool.MaxIdleConns)
		sqlDB.SetConnMaxLifetime(cfg.DBPool.ConnMaxLifetime)
		sqlDB.SetConnMaxIdleTime(cfg.DBPool.ConnMaxIdleTime)
		log.Info("PostgreSQL connection pool configured",
			zap.Int("max_open", cfg.DBPool.MaxOpenConns),
			zap.Int("max_idle", cfg.DBPool.MaxIdleConns))
	}

	return db, nil
}

func New(cfg *config.Config, log *zap.Logger) (*gorm.DB, error) {
	db, err := openConnection(cfg, log)
	if err != nil {
		return nil, err
	}

	log.Info("Running database migrations")
	err = db.AutoMigrate(
		&models.User{},
		&models.TokenBlacklist{},
		&models.RefreshToken{},
		&models.Quiz{},
		&models.Question{},
		&models.QuizAttempt{},
		&models.AttemptAnswer{},
	)
	if err != nil {
		log.Error("Failed to migrate database", zap.Error(err))
		return nil, err
	}

	if err := ensureAdminUser(db, cfg, log); err != nil {
		log.Error("Failed to ensure admin user", zap.Error(err))
		return nil, err
	}

	log.Info("Database initialized successfully")
	return db, nil
}

func ensureAdminUser(db *gorm.DB, cfg *config.Config, log *zap.Logger) error {
	if !models.ValidateUsername(cfg.AdminUsername) {
		log.Error("Invalid ADMIN_USERNAME",
			zap.String("requirement", "6-30 chars, alphanumeric and underscore only"))
		return apperrors.ErrInvalidAdminUsername
	}

	if !models.ValidatePassword(cfg.AdminPassword) {
		log.Error("Invalid ADMIN_PASSWORD",
			zap.String("requirement", "8-72 chars with uppercase, lowercase, and digit"))
		return apperrors.ErrInvalidAdminPassword
	}

	normalizedUsername := models.NormalizeUsername(cfg.AdminUsername)

	var existingUser models.User
	err := db.Where("username = ?", normalizedUsername).First(&existingUser).Error
	if err == nil {
		if !existingUser.IsAdmin {
			now := time.Now()
			if err := db.Model(&existingUser).Updates(map[string]any{
				"is_admin":              true,
				"tokens_invalidated_at": now,
			}).Error; err != nil {
				return err
			}
			log.Info("Updated existing user to admin")
		} else {
			log.Info("Admin user already exists")
		}
		return nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(cfg.AdminPassword), models.BcryptCost)
	if err != nil {
		return err
	}

	adminUser := models.User{
		Username:     normalizedUsername,
		PasswordHash: string(hashedPassword),
		IsAdmin:      true,
	}

	if err := db.Create(&adminUser).Error; err != nil {
		return err
	}

	log.Info("Created admin user")
	return nil
}
