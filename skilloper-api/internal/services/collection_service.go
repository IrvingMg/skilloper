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

const maxCollectionDepth = 50

// GetDescendantIDs returns all descendant collection IDs for a given collection
func (s *CollectionService) GetDescendantIDs(collectionID uint, userID uint) ([]uint, error) {
	var ids []uint
	err := s.db.Raw(`
		WITH RECURSIVE descendants AS (
			SELECT id, 1 as depth FROM collections WHERE id = ? AND user_id = ?
			UNION ALL
			SELECT c.id, d.depth + 1 FROM collections c
			INNER JOIN descendants d ON c.parent_id = d.id
			WHERE d.depth < ?
		)
		SELECT id FROM descendants WHERE id != ?
	`, collectionID, userID, maxCollectionDepth, collectionID).Scan(&ids).Error
	if err != nil {
		return nil, apperrors.ErrFetchCollectionsFailed
	}
	return ids, nil
}

// GetAncestors returns the breadcrumb chain from root to the given collection (excluding the collection itself)
func (s *CollectionService) GetAncestors(collectionID uint) ([]models.CollectionBreadcrumb, error) {
	var ancestors []models.CollectionBreadcrumb
	err := s.db.Raw(`
		WITH RECURSIVE ancestors AS (
			SELECT id, parent_id, name, 0 as depth FROM collections WHERE id = ?
			UNION ALL
			SELECT c.id, c.parent_id, c.name, a.depth + 1
			FROM collections c
			INNER JOIN ancestors a ON c.id = a.parent_id
			WHERE a.depth < ?
		)
		SELECT id, name FROM ancestors WHERE id != ? ORDER BY depth DESC
	`, collectionID, maxCollectionDepth, collectionID).Scan(&ancestors).Error
	if err != nil {
		return nil, apperrors.ErrFetchCollectionsFailed
	}
	return ancestors, nil
}

// GetAncestorsBatch returns ancestors for multiple collections in a single query
func (s *CollectionService) GetAncestorsBatch(collectionIDs []uint) map[uint][]models.CollectionBreadcrumb {
	if len(collectionIDs) == 0 {
		return make(map[uint][]models.CollectionBreadcrumb)
	}

	type ancestorRow struct {
		OriginalID uint   `gorm:"column:original_id"`
		ID         uint   `gorm:"column:id"`
		Name       string `gorm:"column:name"`
		Depth      int    `gorm:"column:depth"`
	}

	var rows []ancestorRow
	err := s.db.Raw(`
		WITH RECURSIVE ancestors AS (
			SELECT id as original_id, id, parent_id, name, 0 as depth FROM collections WHERE id IN ?
			UNION ALL
			SELECT a.original_id, c.id, c.parent_id, c.name, a.depth + 1
			FROM collections c
			INNER JOIN ancestors a ON c.id = a.parent_id
			WHERE a.depth < ?
		)
		SELECT original_id, id, name, depth FROM ancestors WHERE id != original_id ORDER BY original_id, depth DESC
	`, collectionIDs, maxCollectionDepth).Scan(&rows).Error

	result := make(map[uint][]models.CollectionBreadcrumb, len(collectionIDs))
	for _, id := range collectionIDs {
		result[id] = []models.CollectionBreadcrumb{}
	}

	if err != nil {
		s.log.Warn("Failed to batch get ancestors", zap.Error(err))
		return result
	}

	for _, row := range rows {
		result[row.OriginalID] = append(result[row.OriginalID], models.CollectionBreadcrumb{
			ID:   row.ID,
			Name: row.Name,
		})
	}

	return result
}

// GetChildCount returns the number of direct children for a collection
func (s *CollectionService) GetChildCount(collectionID uint) (int, error) {
	var count int64
	if err := s.db.Model(&models.Collection{}).Where("parent_id = ?", collectionID).Count(&count).Error; err != nil {
		return 0, apperrors.ErrFetchCollectionsFailed
	}
	return int(count), nil
}

// GetTotalQuizCount returns the total number of quizzes in a collection and all its descendants
func (s *CollectionService) GetTotalQuizCount(collectionID uint, userID uint) (int, error) {
	var count int64
	err := s.db.Raw(`
		WITH RECURSIVE descendants AS (
			SELECT id, 1 as depth FROM collections WHERE id = ? AND user_id = ?
			UNION ALL
			SELECT c.id, d.depth + 1 FROM collections c
			INNER JOIN descendants d ON c.parent_id = d.id
			WHERE d.depth < ?
		)
		SELECT COUNT(*) FROM quizzes WHERE collection_id IN (SELECT id FROM descendants)
	`, collectionID, userID, maxCollectionDepth).Scan(&count).Error
	if err != nil {
		return 0, apperrors.ErrFetchCollectionsFailed
	}
	return int(count), nil
}

// GetTotalQuizCountBatch returns total quiz counts for multiple collections in a single query
func (s *CollectionService) GetTotalQuizCountBatch(collectionIDs []uint, userID uint) map[uint]int {
	if len(collectionIDs) == 0 {
		return make(map[uint]int)
	}

	type countResult struct {
		CollectionID uint  `gorm:"column:collection_id"`
		Count        int64 `gorm:"column:count"`
	}

	var results []countResult
	err := s.db.Raw(`
		WITH RECURSIVE all_descendants AS (
			SELECT id as root_id, id, 1 as depth FROM collections WHERE id IN ? AND user_id = ?
			UNION ALL
			SELECT ad.root_id, c.id, ad.depth + 1 FROM collections c
			INNER JOIN all_descendants ad ON c.parent_id = ad.id
			WHERE ad.depth < ?
		)
		SELECT ad.root_id as collection_id, COUNT(q.id) as count
		FROM all_descendants ad
		LEFT JOIN quizzes q ON q.collection_id = ad.id
		GROUP BY ad.root_id
	`, collectionIDs, userID, maxCollectionDepth).Scan(&results).Error

	// Initialize all requested IDs with zero (explicit default)
	counts := make(map[uint]int, len(collectionIDs))
	for _, id := range collectionIDs {
		counts[id] = 0
	}

	if err != nil {
		s.log.Warn("Failed to batch get total quiz counts", zap.Error(err))
		return counts
	}

	for _, r := range results {
		counts[r.CollectionID] = int(r.Count)
	}
	return counts
}

type CollectionSummaryRow struct {
	models.Collection
	QuizCount  int64 `gorm:"column:quiz_count"`
	ChildCount int64 `gorm:"column:child_count"`
}

func (s *CollectionService) Create(req models.CreateCollectionRequest, userID uint) (*models.CollectionSummary, error) {
	if req.Name == "" {
		return nil, apperrors.ErrCollectionNameRequired
	}

	if len(req.Name) > models.MaxCollectionNameLength {
		return nil, apperrors.NewValidationError("COLLECTION_NAME_TOO_LONG",
			fmt.Sprintf("collection name exceeds %d character limit", models.MaxCollectionNameLength))
	}

	if req.ParentID != nil {
		var parent models.Collection
		if err := s.db.First(&parent, *req.ParentID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, apperrors.ErrInvalidParentCollection
			}
			return nil, apperrors.ErrFetchCollectionsFailed
		}
		if parent.UserID != userID {
			return nil, apperrors.ErrInvalidParentCollection
		}
	}

	collection := models.Collection{
		UserID:   userID,
		ParentID: req.ParentID,
		Name:     req.Name,
	}

	if err := s.db.Create(&collection).Error; err != nil {
		return nil, apperrors.ErrCreateCollectionFailed
	}

	var ancestors []models.CollectionBreadcrumb
	if req.ParentID != nil {
		var err error
		ancestors, err = s.GetAncestors(*req.ParentID)
		if err != nil {
			s.log.Warn("Failed to get ancestors for new collection", zap.Uint("parent_id", *req.ParentID), zap.Error(err))
		}
	}

	summary := &models.CollectionSummary{
		ID:             collection.ID,
		ParentID:       collection.ParentID,
		Name:           collection.Name,
		QuizCount:      0,
		TotalQuizCount: 0,
		ChildCount:     0,
		Ancestors:      ancestors,
		CreatedAt:      collection.CreatedAt,
		UpdatedAt:      collection.UpdatedAt,
	}

	return summary, nil
}

func (s *CollectionService) GetByID(id uint, userID uint, isAdmin bool) (*models.CollectionSummary, error) {
	var row CollectionSummaryRow

	quizSubquery := s.db.Model(&models.Quiz{}).
		Select("collection_id, COUNT(*) as cnt").
		Where("collection_id IS NOT NULL").
		Group("collection_id")

	childSubquery := s.db.Model(&models.Collection{}).
		Select("parent_id, COUNT(*) as cnt").
		Where("parent_id IS NOT NULL").
		Group("parent_id")

	result := s.db.Table("collections").
		Select("collections.*, COALESCE(q.cnt, 0) as quiz_count, COALESCE(ch.cnt, 0) as child_count").
		Joins("LEFT JOIN (?) as q ON collections.id = q.collection_id", quizSubquery).
		Joins("LEFT JOIN (?) as ch ON collections.id = ch.parent_id", childSubquery).
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

	ancestors, err := s.GetAncestors(id)
	if err != nil {
		s.log.Warn("Failed to get ancestors", zap.Uint("collection_id", id), zap.Error(err))
	}
	totalQuizCount, err := s.GetTotalQuizCount(id, row.UserID)
	if err != nil {
		s.log.Warn("Failed to get total quiz count", zap.Uint("collection_id", id), zap.Error(err))
	}

	summary := &models.CollectionSummary{
		ID:             row.ID,
		ParentID:       row.ParentID,
		Name:           row.Name,
		QuizCount:      int(row.QuizCount),
		TotalQuizCount: totalQuizCount,
		ChildCount:     int(row.ChildCount),
		Ancestors:      ancestors,
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.UpdatedAt,
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

	if params.ParentID != nil {
		baseQuery = baseQuery.Where("parent_id = ?", *params.ParentID)
	} else {
		baseQuery = baseQuery.Where("parent_id IS NULL")
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

	childSubquery := s.db.Model(&models.Collection{}).
		Select("parent_id, COUNT(*) as cnt").
		Where("parent_id IS NOT NULL").
		Group("parent_id")

	result := s.db.Table("collections").
		Select("collections.*, COALESCE(q.cnt, 0) as quiz_count, COALESCE(ch.cnt, 0) as child_count").
		Joins("LEFT JOIN (?) as q ON collections.id = q.collection_id", quizSubquery).
		Joins("LEFT JOIN (?) as ch ON collections.id = ch.parent_id", childSubquery)

	if !isAdmin {
		result = result.Where("collections.user_id = ?", userID)
	}

	if params.Search != "" {
		searchPattern := "%" + escapeLikePattern(strings.ToLower(params.Search)) + "%"
		result = result.Where("LOWER(collections.name) LIKE ? ESCAPE '\\'", searchPattern)
	}

	if params.ParentID != nil {
		result = result.Where("collections.parent_id = ?", *params.ParentID)
	} else {
		result = result.Where("collections.parent_id IS NULL")
	}

	result = result.Order(params.GetOrderBy()).
		Limit(params.Limit).
		Offset(params.Offset).
		Find(&rows)

	if result.Error != nil {
		return models.PaginatedCollectionSummaries{}, apperrors.ErrFetchCollectionsFailed
	}

	// Batch fetch total quiz counts to avoid N+1 queries
	collectionIDs := make([]uint, len(rows))
	for i, row := range rows {
		collectionIDs[i] = row.ID
	}
	totalQuizCounts := s.GetTotalQuizCountBatch(collectionIDs, userID)

	summaries := make([]models.CollectionSummary, 0, len(rows))
	for _, row := range rows {
		summaries = append(summaries, models.CollectionSummary{
			ID:             row.ID,
			ParentID:       row.ParentID,
			Name:           row.Name,
			QuizCount:      int(row.QuizCount),
			TotalQuizCount: totalQuizCounts[row.ID],
			ChildCount:     int(row.ChildCount),
			CreatedAt:      row.CreatedAt,
			UpdatedAt:      row.UpdatedAt,
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

	childCount, err := s.GetChildCount(id)
	if err != nil {
		s.log.Warn("Failed to get child count", zap.Uint("collection_id", id), zap.Error(err))
	}
	totalQuizCount, err := s.GetTotalQuizCount(id, collection.UserID)
	if err != nil {
		s.log.Warn("Failed to get total quiz count", zap.Uint("collection_id", id), zap.Error(err))
	}
	ancestors, err := s.GetAncestors(id)
	if err != nil {
		s.log.Warn("Failed to get ancestors", zap.Uint("collection_id", id), zap.Error(err))
	}

	summary := &models.CollectionSummary{
		ID:             collection.ID,
		ParentID:       collection.ParentID,
		Name:           collection.Name,
		QuizCount:      int(quizCount),
		TotalQuizCount: totalQuizCount,
		ChildCount:     childCount,
		Ancestors:      ancestors,
		CreatedAt:      collection.CreatedAt,
		UpdatedAt:      collection.UpdatedAt,
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
