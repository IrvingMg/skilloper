package models

// Valid type filter values
var validTypes = map[string]bool{
	"":         true,
	"practice": true,
	"exam":     true,
}

// Valid sort options for quizzes
var validQuizSorts = map[string]string{
	"":           "quizzes.created_at DESC", // default
	"date_desc":  "quizzes.created_at DESC",
	"date_asc":   "quizzes.created_at ASC",
	"title_asc":  "quizzes.title ASC",
	"title_desc": "quizzes.title DESC",
}

// Valid sort options for attempts
var validAttemptSorts = map[string]string{
	"":           "created_at DESC", // default
	"date_desc":  "created_at DESC",
	"date_asc":   "created_at ASC",
	"score_desc": "score DESC",
	"score_asc":  "score ASC",
	"title_asc":  "quiz_title ASC",
	"title_desc": "quiz_title DESC",
}

// PaginationParams holds common pagination and filter parameters
type PaginationParams struct {
	Limit  int    `form:"limit"`
	Offset int    `form:"offset"`
	Search string `form:"search"`
	Type   string `form:"type"`
	Sort   string `form:"sort"`
}

// Validate ensures pagination params are within acceptable bounds
// Returns true if valid, false if type is invalid
func (p *PaginationParams) Validate() bool {
	if p.Limit <= 0 {
		p.Limit = 20
	}
	if p.Limit > 100 {
		p.Limit = 100
	}
	if p.Offset < 0 {
		p.Offset = 0
	}
	return validTypes[p.Type]
}

// GetQuizOrderBy returns the SQL ORDER BY clause for quizzes
// Falls back to default (date_desc) if sort value is invalid
func (p *PaginationParams) GetQuizOrderBy() string {
	if orderBy, ok := validQuizSorts[p.Sort]; ok {
		return orderBy
	}
	return validQuizSorts[""]
}

// GetAttemptOrderBy returns the SQL ORDER BY clause for attempts
// Falls back to default (date_desc) if sort value is invalid
func (p *PaginationParams) GetAttemptOrderBy() string {
	if orderBy, ok := validAttemptSorts[p.Sort]; ok {
		return orderBy
	}
	return validAttemptSorts[""]
}

// PaginationMeta holds pagination metadata for responses
type PaginationMeta struct {
	Limit      int  `json:"limit"`
	Offset     int  `json:"offset"`
	TotalCount int  `json:"total_count"`
	HasMore    bool `json:"has_more"`
}

// PaginatedQuizSummaries wraps quiz summaries with pagination
type PaginatedQuizSummaries struct {
	Data       []QuizSummary  `json:"data"`
	Pagination PaginationMeta `json:"pagination"`
}

// NewPaginatedQuizSummaries creates a paginated response for quiz summaries
func NewPaginatedQuizSummaries(data []QuizSummary, limit, offset, totalCount int) PaginatedQuizSummaries {
	hasMore := offset+len(data) < totalCount
	return PaginatedQuizSummaries{
		Data: data,
		Pagination: PaginationMeta{
			Limit:      limit,
			Offset:     offset,
			TotalCount: totalCount,
			HasMore:    hasMore,
		},
	}
}

// PaginatedAttemptSummaries wraps attempt summaries with pagination
type PaginatedAttemptSummaries struct {
	Data       []AttemptSummaryResponse `json:"data"`
	Pagination PaginationMeta           `json:"pagination"`
}

// NewPaginatedAttemptSummaries creates a paginated response for attempt summaries
func NewPaginatedAttemptSummaries(data []AttemptSummaryResponse, limit, offset, totalCount int) PaginatedAttemptSummaries {
	hasMore := offset+len(data) < totalCount
	return PaginatedAttemptSummaries{
		Data: data,
		Pagination: PaginationMeta{
			Limit:      limit,
			Offset:     offset,
			TotalCount: totalCount,
			HasMore:    hasMore,
		},
	}
}
