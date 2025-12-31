package models

// Valid type filter values
var validTypes = map[string]bool{
	"":         true,
	"practice": true,
	"exam":     true,
}

// PaginationParams holds common pagination and filter parameters
type PaginationParams struct {
	Limit  int    `form:"limit"`
	Offset int    `form:"offset"`
	Search string `form:"search"`
	Type   string `form:"type"`
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

// PaginationMeta holds pagination metadata for responses
type PaginationMeta struct {
	Limit      int  `json:"limit"`
	Offset     int  `json:"offset"`
	TotalCount int  `json:"total_count"`
	HasMore    bool `json:"has_more"`
}

// PaginatedQuestionnaireSummaries wraps questionnaire summaries with pagination
type PaginatedQuestionnaireSummaries struct {
	Data       []QuestionnaireSummary `json:"data"`
	Pagination PaginationMeta         `json:"pagination"`
}

// NewPaginatedQuestionnaireSummaries creates a paginated response for questionnaire summaries
func NewPaginatedQuestionnaireSummaries(data []QuestionnaireSummary, limit, offset, totalCount int) PaginatedQuestionnaireSummaries {
	hasMore := offset+len(data) < totalCount
	return PaginatedQuestionnaireSummaries{
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
