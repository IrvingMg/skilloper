package services

import (
	"errors"
	"fmt"
	"strings"

	"go.uber.org/zap"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type CollectionService struct {
	db  *gorm.DB
	log *zap.Logger
}

func NewCollectionService(db *gorm.DB, log *zap.Logger) *CollectionService {
	return &CollectionService{
		db:  db,
		log: log,
	}
}

type CollectionSummaryRow struct {
	models.Collection
	QuizCount int64 `gorm:"column:quiz_count"`
}

func (s *CollectionService) Create(req models.CreateCollectionRequest, userID uint) (*models.CollectionSummary, error) {
	if req.Name == "" {
		return nil, apperrors.ErrCollectionNameRequired
	}

	if len(req.Name) > models.MaxCollectionNameLength {
		return nil, apperrors.NewValidationError("COLLECTION_NAME_TOO_LONG",
			fmt.Sprintf("collection name exceeds %d character limit", models.MaxCollectionNameLength))
	}

	collection := models.Collection{
		UserID: userID,
		Name:   req.Name,
	}

	if err := s.db.Create(&collection).Error; err != nil {
		return nil, apperrors.ErrCreateCollectionFailed
	}

	summary := &models.CollectionSummary{
		ID:        collection.ID,
		Name:      collection.Name,
		QuizCount: 0,
		CreatedAt: collection.CreatedAt,
		UpdatedAt: collection.UpdatedAt,
	}

	return summary, nil
}

func (s *CollectionService) GetByID(id uint, userID uint, isAdmin bool) (*models.CollectionSummary, error) {
	var row CollectionSummaryRow

	quizSubquery := s.db.Model(&models.Quiz{}).
		Select("collection_id, COUNT(*) as cnt").
		Where("collection_id IS NOT NULL").
		Group("collection_id")

	result := s.db.Table("collections").
		Select("collections.*, COALESCE(q.cnt, 0) as quiz_count").
		Joins("LEFT JOIN (?) as q ON collections.id = q.collection_id", quizSubquery).
		Where("collections.id = ?", id).
		First(&row)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrCollectionNotFound
		}
		return nil, apperrors.ErrFetchCollectionsFailed
	}

	if !isAdmin && row.UserID != userID {
		return nil, apperrors.ErrNotCollectionOwner
	}

	summary := &models.CollectionSummary{
		ID:        row.ID,
		Name:      row.Name,
		QuizCount: int(row.QuizCount),
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}

	return summary, nil
}

func (s *CollectionService) GetPaginatedSummaries(params models.CollectionPaginationParams, userID uint, isAdmin bool) (models.PaginatedCollectionSummaries, error) {
	baseQuery := s.db.Model(&models.Collection{})
	if !isAdmin {
		baseQuery = baseQuery.Where("user_id = ?", userID)
	}

	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		baseQuery = baseQuery.Where("LOWER(name) LIKE ? ESCAPE '\\'", searchPattern)
	}

	var totalCount int64
	if err := baseQuery.Count(&totalCount).Error; err != nil {
		return models.PaginatedCollectionSummaries{}, apperrors.ErrFetchCollectionsFailed
	}

	var rows []CollectionSummaryRow
	quizSubquery := s.db.Model(&models.Quiz{}).
		Select("collection_id, COUNT(*) as cnt").
		Where("collection_id IS NOT NULL").
		Group("collection_id")

	result := s.db.Table("collections").
		Select("collections.*, COALESCE(q.cnt, 0) as quiz_count").
		Joins("LEFT JOIN (?) as q ON collections.id = q.collection_id", quizSubquery)

	if !isAdmin {
		result = result.Where("collections.user_id = ?", userID)
	}

	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		result = result.Where("LOWER(collections.name) LIKE ? ESCAPE '\\'", searchPattern)
	}

	result = result.Order(params.GetOrderBy()).
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&rows)

	if result.Error != nil {
		return models.PaginatedCollectionSummaries{}, apperrors.ErrFetchCollectionsFailed
	}

	summaries := make([]models.CollectionSummary, 0, len(rows))
	for _, row := range rows {
		summaries = append(summaries, models.CollectionSummary{
			ID:        row.ID,
			Name:      row.Name,
			QuizCount: int(row.QuizCount),
			CreatedAt: row.CreatedAt,
			UpdatedAt: row.UpdatedAt,
		})
	}

	return models.NewPaginatedCollectionSummaries(summaries, params.Limit, params.Offset, int(totalCount)), nil
}

func (s *CollectionService) Update(id uint, req models.CreateCollectionRequest, userID uint, isAdmin bool) (*models.CollectionSummary, error) {
	if req.Name == "" {
		return nil, apperrors.ErrCollectionNameRequired
	}

	if len(req.Name) > models.MaxCollectionNameLength {
		return nil, apperrors.NewValidationError("COLLECTION_NAME_TOO_LONG",
			fmt.Sprintf("collection name exceeds %d character limit", models.MaxCollectionNameLength))
	}

	var collection models.Collection
	if err := s.db.First(&collection, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.ErrCollectionNotFound
		}
		return nil, apperrors.ErrFetchCollectionsFailed
	}

	if !isAdmin && collection.UserID != userID {
		return nil, apperrors.ErrNotCollectionOwner
	}

	collection.Name = req.Name

	if err := s.db.Save(&collection).Error; err != nil {
		return nil, apperrors.ErrUpdateCollectionFailed
	}

	var quizCount int64
	s.db.Model(&models.Quiz{}).Where("collection_id = ?", id).Count(&quizCount)

	summary := &models.CollectionSummary{
		ID:        collection.ID,
		Name:      collection.Name,
		QuizCount: int(quizCount),
		CreatedAt: collection.CreatedAt,
		UpdatedAt: collection.UpdatedAt,
	}

	return summary, nil
}

func (s *CollectionService) Delete(id uint, userID uint, isAdmin bool) error {
	var collection models.Collection
	if err := s.db.First(&collection, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return apperrors.ErrCollectionNotFound
		}
		return apperrors.ErrFetchCollectionsFailed
	}

	if !isAdmin && collection.UserID != userID {
		return apperrors.ErrNotCollectionOwner
	}

	if err := s.db.Delete(&collection).Error; err != nil {
		return apperrors.ErrDeleteCollectionFailed
	}

	return nil
}
