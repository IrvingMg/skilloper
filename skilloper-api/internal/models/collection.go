package models

import "time"

const (
	MaxCollectionNameLength = 100
)

// Valid sort options for collections
var validCollectionSorts = map[string]string{
	"":          "collections.created_at DESC",
	"date_desc": "collections.created_at DESC",
	"date_asc":  "collections.created_at ASC",
	"name_asc":  "collections.name ASC",
	"name_desc": "collections.name DESC",
}

type Collection struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"user_id" gorm:"not null;index;constraint:OnDelete:CASCADE"`
	Name      string    `json:"name" gorm:"not null;size:100"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CollectionSummary struct {
	ID        uint      `json:"id"`
	Name      string    `json:"name"`
	QuizCount int       `json:"quiz_count"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateCollectionRequest struct {
	Name string `json:"name" binding:"required"`
}

type UpdateQuizCollectionRequest struct {
	CollectionID *uint `json:"collection_id"`
}

// CollectionPaginationParams holds pagination and filter parameters for collections
type CollectionPaginationParams struct {
	Limit  int    `form:"limit"`
	Offset int    `form:"offset"`
	Search string `form:"search"`
	Sort   string `form:"sort"`
}

// Validate ensures pagination params are within acceptable bounds
func (p *CollectionPaginationParams) Validate() {
	if p.Limit <= 0 {
		p.Limit = 20
	}
	if p.Limit > 100 {
		p.Limit = 100
	}
	if p.Offset < 0 {
		p.Offset = 0
	}
}

// GetOrderBy returns the SQL ORDER BY clause for collections
func (p *CollectionPaginationParams) GetOrderBy() string {
	if orderBy, ok := validCollectionSorts[p.Sort]; ok {
		return orderBy
	}
	return validCollectionSorts[""]
}

// PaginatedCollectionSummaries wraps collection summaries with pagination
type PaginatedCollectionSummaries struct {
	Data       []CollectionSummary `json:"data"`
	Pagination PaginationMeta      `json:"pagination"`
}

// NewPaginatedCollectionSummaries creates a paginated response for collection summaries
func NewPaginatedCollectionSummaries(data []CollectionSummary, limit, offset, totalCount int) PaginatedCollectionSummaries {
	hasMore := offset+len(data) < totalCount
	return PaginatedCollectionSummaries{
		Data: data,
		Pagination: PaginationMeta{
			Limit:      limit,
			Offset:     offset,
			TotalCount: totalCount,
			HasMore:    hasMore,
		},
	}
}
