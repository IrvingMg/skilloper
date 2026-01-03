package shuffle

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sync"
	"time"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type QuestionShuffler struct {
	rng *rand.Rand
	mu  sync.Mutex
}

func New() *QuestionShuffler {
	return &QuestionShuffler{
		rng: rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// rngIntn returns a random int in [0, n) with thread-safety
func (qs *QuestionShuffler) rngIntn(n int) int {
	qs.mu.Lock()
	defer qs.mu.Unlock()
	return qs.rng.Intn(n)
}

// rngShuffle shuffles a slice with thread-safety
func (qs *QuestionShuffler) rngShuffle(n int, swap func(i, j int)) {
	qs.mu.Lock()
	defer qs.mu.Unlock()
	qs.rng.Shuffle(n, swap)
}

func (qs *QuestionShuffler) ShuffleQuestion(question models.Question) (*models.QuestionResponse, error) {
	switch question.QuestionType {
	case models.QuestionTypeMultipleChoice:
		return qs.shuffleMultipleChoiceQuestion(question)
	default:
		return qs.shuffleSingleChoiceQuestion(question)
	}
}

func (qs *QuestionShuffler) shuffleSingleChoiceQuestion(question models.Question) (*models.QuestionResponse, error) {
	var originalOptions []string
	if err := json.Unmarshal([]byte(question.Options), &originalOptions); err != nil {
		return nil, fmt.Errorf("failed to parse options: %w", err)
	}

	// Validate correct answer index bounds
	if question.CorrectAnswer < 0 || question.CorrectAnswer >= len(originalOptions) {
		return nil, fmt.Errorf("invalid correct answer index %d for %d options", question.CorrectAnswer, len(originalOptions))
	}

	var alternativeQuestions []string
	if question.AlternativeQuestions != "" {
		if err := json.Unmarshal([]byte(question.AlternativeQuestions), &alternativeQuestions); err != nil {
			// Log but continue - alternative questions are optional
			alternativeQuestions = nil
		}
	}

	var alternativeOptions []string
	if question.AlternativeOptions != "" {
		if err := json.Unmarshal([]byte(question.AlternativeOptions), &alternativeOptions); err != nil {
			alternativeOptions = nil
		}
	}

	var alternativeAnswers []string
	if question.AlternativeAnswers != "" {
		if err := json.Unmarshal([]byte(question.AlternativeAnswers), &alternativeAnswers); err != nil {
			alternativeAnswers = nil
		}
	}

	response := &models.QuestionResponse{}
	response.ID = question.ID
	response.QuestionType = question.QuestionType
	response.Question = question.QuestionText
	response.Code = question.Code
	response.Language = question.Language
	response.Explanation = question.Explanation

	if len(alternativeQuestions) > 0 {
		allTexts := append([]string{question.QuestionText}, alternativeQuestions...)
		response.Question = allTexts[qs.rngIntn(len(allTexts))]
	}

	finalOptions := make([]string, len(originalOptions))
	copy(finalOptions, originalOptions)

	correctAnswerText := originalOptions[question.CorrectAnswer]
	if len(alternativeAnswers) > 0 {
		allCorrectTexts := append([]string{correctAnswerText}, alternativeAnswers...)
		correctAnswerText = allCorrectTexts[qs.rngIntn(len(allCorrectTexts))]
		finalOptions[question.CorrectAnswer] = correctAnswerText
	}

	// Shuffler only shuffles - option limiting is handled during questionnaire creation

	newCorrectIndex := qs.shuffleOptionsWithCorrectTracking(finalOptions, correctAnswerText)

	response.Options = finalOptions
	response.CorrectAnswer = newCorrectIndex // Keep 0-based indexing

	return response, nil
}

func (qs *QuestionShuffler) shuffleMultipleChoiceQuestion(question models.Question) (*models.QuestionResponse, error) {
	var originalOptions []string
	if err := json.Unmarshal([]byte(question.Options), &originalOptions); err != nil {
		return nil, fmt.Errorf("failed to parse options: %w", err)
	}

	var originalCorrectAnswers []int
	if err := json.Unmarshal([]byte(question.CorrectAnswers), &originalCorrectAnswers); err != nil {
		return nil, fmt.Errorf("failed to parse correct answers: %w", err)
	}

	// Validate all correct answer indices are in bounds
	for _, idx := range originalCorrectAnswers {
		if idx < 0 || idx >= len(originalOptions) {
			return nil, fmt.Errorf("invalid correct answer index %d for %d options", idx, len(originalOptions))
		}
	}

	var alternativeQuestions []string
	if question.AlternativeQuestions != "" {
		if err := json.Unmarshal([]byte(question.AlternativeQuestions), &alternativeQuestions); err != nil {
			alternativeQuestions = nil
		}
	}

	var alternativeOptions []string
	if question.AlternativeOptions != "" {
		if err := json.Unmarshal([]byte(question.AlternativeOptions), &alternativeOptions); err != nil {
			alternativeOptions = nil
		}
	}

	response := &models.QuestionResponse{}
	response.ID = question.ID
	response.QuestionType = models.QuestionTypeMultipleChoice
	response.Question = question.QuestionText
	response.Code = question.Code
	response.Language = question.Language
	response.Explanation = question.Explanation

	if len(alternativeQuestions) > 0 {
		allTexts := append([]string{question.QuestionText}, alternativeQuestions...)
		response.Question = allTexts[qs.rngIntn(len(allTexts))]
	}

	finalOptions := make([]string, len(originalOptions))
	copy(finalOptions, originalOptions)

	newCorrectAnswers := qs.shuffleOptionsWithMultipleCorrectTracking(finalOptions, originalCorrectAnswers)

	response.Options = finalOptions
	// Keep 0-based indexing
	response.CorrectAnswers = newCorrectAnswers
	return response, nil
}

// shuffleOptionsWithMultipleCorrectTracking shuffles options in-place and returns new correct indices
func (qs *QuestionShuffler) shuffleOptionsWithMultipleCorrectTracking(options []string, correctIndices []int) []int {
	// Store correct answer texts before shuffling, skipping invalid indices
	correctTexts := make([]string, 0, len(correctIndices))
	for _, idx := range correctIndices {
		if idx >= 0 && idx < len(options) {
			correctTexts = append(correctTexts, options[idx])
		}
	}

	indices := make([]int, len(options))
	for i := range indices {
		indices[i] = i
	}

	qs.rngShuffle(len(indices), func(i, j int) {
		indices[i], indices[j] = indices[j], indices[i]
	})

	shuffledOptions := make([]string, len(options))
	newCorrectIndices := make([]int, 0, len(correctTexts))

	for newPos, oldPos := range indices {
		shuffledOptions[newPos] = options[oldPos]
		for _, correctText := range correctTexts {
			if options[oldPos] == correctText {
				newCorrectIndices = append(newCorrectIndices, newPos)
				break
			}
		}
	}

	copy(options, shuffledOptions)
	return newCorrectIndices
}

func (qs *QuestionShuffler) shuffleOptionsWithCorrectTracking(options []string, correctAnswerText string) int {
	indices := make([]int, len(options))
	for i := range indices {
		indices[i] = i
	}

	qs.rngShuffle(len(indices), func(i, j int) {
		indices[i], indices[j] = indices[j], indices[i]
	})

	shuffledOptions := make([]string, len(options))
	newCorrectIndex := -1

	for newPos, oldPos := range indices {
		shuffledOptions[newPos] = options[oldPos]
		if options[oldPos] == correctAnswerText {
			newCorrectIndex = newPos
		}
	}

	copy(options, shuffledOptions)
	return newCorrectIndex
}

func (qs *QuestionShuffler) ShuffleQuestions(questions []models.Question) ([]models.QuestionResponse, error) {
	result := make([]models.QuestionResponse, 0, len(questions))

	for _, question := range questions {
		shuffled, err := qs.ShuffleQuestion(question)
		if err != nil {
			return nil, err
		}
		result = append(result, *shuffled)
	}

	return result, nil
}
