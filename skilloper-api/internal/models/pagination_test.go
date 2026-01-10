package models

import "testing"

func TestPaginationParams_Validate(t *testing.T) {
	tests := []struct {
		name           string
		params         PaginationParams
		wantValid      bool
		wantLimit      int
		wantOffset     int
	}{
		{
			name:       "zero limit defaults to 20",
			params:     PaginationParams{Limit: 0, Offset: 0, Type: ""},
			wantValid:  true,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "negative limit defaults to 20",
			params:     PaginationParams{Limit: -5, Offset: 0, Type: ""},
			wantValid:  true,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "limit over 100 caps to 100",
			params:     PaginationParams{Limit: 150, Offset: 0, Type: ""},
			wantValid:  true,
			wantLimit:  100,
			wantOffset: 0,
		},
		{
			name:       "negative offset resets to 0",
			params:     PaginationParams{Limit: 20, Offset: -10, Type: ""},
			wantValid:  true,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "valid type practice",
			params:     PaginationParams{Limit: 20, Offset: 0, Type: "practice"},
			wantValid:  true,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "valid type exam",
			params:     PaginationParams{Limit: 20, Offset: 0, Type: "exam"},
			wantValid:  true,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "invalid type returns false",
			params:     PaginationParams{Limit: 20, Offset: 0, Type: "invalid"},
			wantValid:  false,
			wantLimit:  20,
			wantOffset: 0,
		},
		{
			name:       "valid limit and offset preserved",
			params:     PaginationParams{Limit: 50, Offset: 100, Type: ""},
			wantValid:  true,
			wantLimit:  50,
			wantOffset: 100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.params.Validate()
			if got != tt.wantValid {
				t.Errorf("Validate() = %v, want %v", got, tt.wantValid)
			}
			if tt.params.Limit != tt.wantLimit {
				t.Errorf("Limit = %d, want %d", tt.params.Limit, tt.wantLimit)
			}
			if tt.params.Offset != tt.wantOffset {
				t.Errorf("Offset = %d, want %d", tt.params.Offset, tt.wantOffset)
			}
		})
	}
}

func TestPaginationParams_GetQuizOrderBy(t *testing.T) {
	tests := []struct {
		name string
		sort string
		want string
	}{
		{"empty defaults to date desc", "", "quizzes.created_at DESC"},
		{"date_desc", "date_desc", "quizzes.created_at DESC"},
		{"date_asc", "date_asc", "quizzes.created_at ASC"},
		{"title_asc", "title_asc", "quizzes.title ASC"},
		{"title_desc", "title_desc", "quizzes.title DESC"},
		{"invalid defaults to date desc", "invalid_sort", "quizzes.created_at DESC"},
		{"sql injection attempt defaults", "created_at; DROP TABLE", "quizzes.created_at DESC"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := PaginationParams{Sort: tt.sort}
			if got := p.GetQuizOrderBy(); got != tt.want {
				t.Errorf("GetQuizOrderBy() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestPaginationParams_GetAttemptOrderBy(t *testing.T) {
	tests := []struct {
		name string
		sort string
		want string
	}{
		{"empty defaults to date desc", "", "created_at DESC"},
		{"date_desc", "date_desc", "created_at DESC"},
		{"date_asc", "date_asc", "created_at ASC"},
		{"score_desc", "score_desc", "score DESC"},
		{"score_asc", "score_asc", "score ASC"},
		{"title_asc", "title_asc", "quiz_title ASC"},
		{"title_desc", "title_desc", "quiz_title DESC"},
		{"invalid defaults to date desc", "unknown", "created_at DESC"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := PaginationParams{Sort: tt.sort}
			if got := p.GetAttemptOrderBy(); got != tt.want {
				t.Errorf("GetAttemptOrderBy() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestNewPaginatedQuizSummaries(t *testing.T) {
	tests := []struct {
		name       string
		dataLen    int
		limit      int
		offset     int
		totalCount int
		wantMore   bool
	}{
		{"has more pages", 20, 20, 0, 50, true},
		{"no more pages - exact", 20, 20, 30, 50, false},
		{"no more pages - last partial", 10, 20, 40, 50, false},
		{"empty data with total", 0, 20, 0, 0, false},
		{"single page", 5, 20, 0, 5, false},
		{"offset at end", 0, 20, 50, 50, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data := make([]QuizSummary, tt.dataLen)
			result := NewPaginatedQuizSummaries(data, tt.limit, tt.offset, tt.totalCount)

			if result.Pagination.HasMore != tt.wantMore {
				t.Errorf("HasMore = %v, want %v", result.Pagination.HasMore, tt.wantMore)
			}
			if result.Pagination.Limit != tt.limit {
				t.Errorf("Limit = %d, want %d", result.Pagination.Limit, tt.limit)
			}
			if result.Pagination.Offset != tt.offset {
				t.Errorf("Offset = %d, want %d", result.Pagination.Offset, tt.offset)
			}
			if result.Pagination.TotalCount != tt.totalCount {
				t.Errorf("TotalCount = %d, want %d", result.Pagination.TotalCount, tt.totalCount)
			}
			if len(result.Data) != tt.dataLen {
				t.Errorf("Data length = %d, want %d", len(result.Data), tt.dataLen)
			}
		})
	}
}

func TestNewPaginatedAttemptSummaries(t *testing.T) {
	tests := []struct {
		name       string
		dataLen    int
		limit      int
		offset     int
		totalCount int
		wantMore   bool
	}{
		{"has more pages", 20, 20, 0, 100, true},
		{"no more pages", 15, 20, 85, 100, false},
		{"exactly fills total", 20, 20, 80, 100, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data := make([]AttemptSummaryResponse, tt.dataLen)
			result := NewPaginatedAttemptSummaries(data, tt.limit, tt.offset, tt.totalCount)

			if result.Pagination.HasMore != tt.wantMore {
				t.Errorf("HasMore = %v, want %v", result.Pagination.HasMore, tt.wantMore)
			}
		})
	}
}
