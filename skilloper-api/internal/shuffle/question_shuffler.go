package shuffle

import (
	"encoding/json"
	"math/rand"
	"time"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type QuestionShuffler struct {
	rng *rand.Rand
}

func New() *QuestionShuffler {
	return &QuestionShuffler{
		rng: rand.New(rand.NewSource(time.Now().UnixNano())),
	}
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
		return nil, err
	}

	var alternativeQuestions []string
	if question.AlternativeQuestions != "" {
		json.Unmarshal([]byte(question.AlternativeQuestions), &alternativeQuestions)
	}

	var alternativeOptions []string
	if question.AlternativeOptions != "" {
		json.Unmarshal([]byte(question.AlternativeOptions), &alternativeOptions)
	}

	var alternativeAnswers []string
	if question.AlternativeAnswers != "" {
		json.Unmarshal([]byte(question.AlternativeAnswers), &alternativeAnswers)
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
		response.Question = allTexts[qs.rng.Intn(len(allTexts))]
	}

	finalOptions := make([]string, len(originalOptions))
	copy(finalOptions, originalOptions)

	correctAnswerText := originalOptions[question.CorrectAnswer]
	if len(alternativeAnswers) > 0 {
		allCorrectTexts := append([]string{correctAnswerText}, alternativeAnswers...)
		correctAnswerText = allCorrectTexts[qs.rng.Intn(len(allCorrectTexts))]
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
		return nil, err
	}

	var originalCorrectAnswers []int
	if err := json.Unmarshal([]byte(question.CorrectAnswers), &originalCorrectAnswers); err != nil {
		return nil, err
	}

	var alternativeQuestions []string
	if question.AlternativeQuestions != "" {
		json.Unmarshal([]byte(question.AlternativeQuestions), &alternativeQuestions)
	}

	var alternativeOptions []string
	if question.AlternativeOptions != "" {
		json.Unmarshal([]byte(question.AlternativeOptions), &alternativeOptions)
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
		response.Question = allTexts[qs.rng.Intn(len(allTexts))]
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
	// Store correct answer texts before shuffling
	correctTexts := make([]string, len(correctIndices))
	for i, idx := range correctIndices {
		if idx >= 0 && idx < len(options) {
			correctTexts[i] = options[idx]
		}
	}

	indices := make([]int, len(options))
	for i := range indices {
		indices[i] = i
	}

	qs.rng.Shuffle(len(indices), func(i, j int) {
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

	qs.rng.Shuffle(len(indices), func(i, j int) {
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
