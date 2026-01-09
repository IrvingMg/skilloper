package database

import (
	"go.uber.org/zap"
	"gorm.io/gorm"

	"github.com/irvingmg/skilloper/skilloper-api/internal/config"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

func seedSampleData(db *gorm.DB, cfg *config.Config, logger *zap.Logger) error {
	normalizedUsername := models.NormalizeUsername(cfg.AdminUsername)
	var adminUser models.User
	if err := db.Where("username = ?", normalizedUsername).First(&adminUser).Error; err != nil {
		logger.Error("Admin user not found for quiz seeding")
		return err
	}

	// Practice mode quiz with immediate feedback
	practiceQuiz := models.Quiz{
		UserID:      adminUser.ID,
		Title:       "Go Fundamentals",
		Description: "Practice Go concepts with immediate feedback",
		Type:        "practice",
		MaxOptions:  4, // Limit to 4 options per question
		Questions: []models.Question{
			{
				QuestionType:         "single_choice",
				QuestionText:         "What is the primary purpose of Go's garbage collector?",
				AlternativeQuestions: `["What does Go's garbage collector do?", "Why does Go use a garbage collector?"]`,
				Options:              `["Compile code faster", "Automatically manage memory allocation and deallocation", "Handle network connections", "Optimize CPU usage"]`,
				AlternativeOptions:   `["Improve performance", "Handle database connections", "Manage file operations"]`,
				CorrectAnswer:        1, // 0-based: "Automatically manage memory..." is option 1
				AlternativeAnswers:   `["Manages memory automatically", "Handles memory allocation and cleanup"]`,
				Explanation:          "Go's garbage collector automatically manages memory by tracking allocated objects and freeing memory that is no longer referenced, preventing memory leaks.",
			},
			{
				QuestionType:         "single_choice",
				QuestionText:         "Which method is used to add elements to a slice in Go?",
				AlternativeQuestions: `["How do you append to a slice in Go?", "What function adds elements to a Go slice?"]`,
				Code:                 "s := []int{1, 2, 3}",
				Language:             "go",
				Options:              `["append()", "push()", "add()", "insert()"]`,
				AlternativeOptions:   `["concat()", "merge()", "join()"]`,
				CorrectAnswer:        0, // 0-based: "append()" is option 0
				AlternativeAnswers:   `["append() function", "The append built-in"]`,
				Explanation:          "In Go, append() is the built-in function used to add elements to a slice. It returns a new slice with the elements appended.",
			},
			{
				QuestionType:  "single_choice",
				QuestionText:  "What does this goroutine code print?",
				Code:          "package main\n\nimport (\n    \"fmt\"\n    \"time\"\n)\n\nfunc main() {\n    go fmt.Println(\"goroutine\")\n    fmt.Println(\"main\")\n    time.Sleep(time.Millisecond)\n}",
				Language:      "go",
				Options:       `["goroutine\\nmain", "main\\ngoroutine", "main", "goroutine"]`,
				CorrectAnswer: 1, // 0-based: "main\\ngoroutine" is option 1
				Explanation:   "The main function prints 'main' first, then the goroutine runs and prints 'goroutine'. The Sleep ensures the goroutine has time to execute.",
			},
		},
	}

	// Exam mode quiz - Python
	examQuiz := models.Quiz{
		UserID:      adminUser.ID,
		Title:       "Python Assessment",
		Description: "Test your Python knowledge in exam mode",
		Type:        "exam",
		MaxOptions:  4, // Limit to 4 options per question
		Questions: []models.Question{
			{
				QuestionType:  "single_choice",
				QuestionText:  "Which Python principle emphasizes that there should be one obvious way to do something?",
				Options:       `["DRY (Don't Repeat Yourself)", "The Zen of Python", "SOLID principles", "Duck typing"]`,
				CorrectAnswer: 1, // 0-based: "The Zen of Python" is option 1
				Explanation:   "The Zen of Python includes the principle 'There should be one-- and preferably only one --obvious way to do it', emphasizing Python's philosophy of simplicity and readability.",
			},
			{
				QuestionType:  "single_choice",
				QuestionText:  "What does this list comprehension create?",
				Code:          "numbers = [x**2 for x in range(5) if x % 2 == 0]\nprint(numbers)",
				Language:      "python",
				Options:       `["[0, 4, 16]", "[0, 1, 4, 9, 16]", "[1, 9]", "[0, 2, 4]"]`,
				CorrectAnswer: 0, // 0-based: "[0, 4, 16]" is option 0
				Explanation:   "The list comprehension squares even numbers from 0 to 4. Even numbers are 0, 2, 4, so their squares are [0, 4, 16].",
			},
			{
				QuestionType:  "single_choice",
				QuestionText:  "What will this Python code output?",
				Code:          "def modify_list(lst):\n    lst.append(4)\n    lst = [1, 2, 3]\n    lst.append(5)\n\nmy_list = [1, 2]\nmodify_list(my_list)\nprint(my_list)",
				Language:      "python",
				Options:       `["[1, 2]", "[1, 2, 4]", "[1, 2, 3, 5]", "[1, 2, 4, 5]"]`,
				CorrectAnswer: 1, // 0-based: "[1, 2, 4]" is option 1
				Explanation:   "The function first appends 4 to the original list, then creates a new local list. The original list remains [1, 2, 4] since the reassignment only affects the local variable.",
			},
		},
	}

	// Mixed question types quiz - JavaScript
	mixedQuiz := models.Quiz{
		UserID:      adminUser.ID,
		Title:       "JavaScript Mixed Types",
		Description: "Practice JavaScript with both single-choice and multiple-choice questions",
		Type:        "practice",
		MaxOptions:  3, // Limit to 3 options per question for this one
		Questions: []models.Question{
			{
				QuestionType:       models.QuestionTypeMultipleChoice,
				QuestionText:       "Which of the following are valid JavaScript data types?",
				Options:            `["undefined", "bigint", "string"]`,
				AlternativeOptions: `["number", "boolean", "object", "function", "symbol"]`,
				CorrectAnswers:     `[0, 1, 2]`, // 0-based: All are valid (options 0, 1, 2)
				Explanation:        "All listed options are valid JavaScript data types. JavaScript has primitive types (string, number, boolean, undefined, symbol, bigint) and non-primitive types (object, function).",
			},
			{
				QuestionType:       models.QuestionTypeMultipleChoice,
				QuestionText:       "Which methods can be used to iterate over an array in JavaScript?",
				Code:               "const arr = [1, 2, 3, 4, 5];",
				Language:           "javascript",
				Options:            `["for loop", "forEach()", "map()"]`,
				AlternativeOptions: `["filter()", "reduce()", "for...of", "while loop"]`,
				CorrectAnswers:     `[0, 1, 2]`, // 0-based: for loop, forEach, map can iterate (options 0, 1, 2)
				Explanation:        "for loop, forEach(), map(), for...of, and while loop can all be used to iterate over arrays. filter() and reduce() transform data rather than just iterate.",
			},
			{
				QuestionType:  models.QuestionTypeSingleChoice,
				QuestionText:  "JavaScript is a statically typed language.",
				Options:       `["False", "True"]`,
				CorrectAnswer: 0, // 0-based: "False" is option 0
				Explanation:   "False. JavaScript is dynamically typed, meaning variable types are determined at runtime rather than compile time.",
			},
			{
				QuestionType:       models.QuestionTypeSingleChoice,
				QuestionText:       "What does 'this' refer to in a regular function in JavaScript?",
				Options:            `["The function itself", "The global object (window in browsers)", "undefined"]`,
				AlternativeOptions: `["The parent object", "The window object", "null"]`,
				CorrectAnswer:      1,
				Explanation:        "In a regular function call, 'this' refers to the global object (window in browsers, global in Node.js) in non-strict mode, or undefined in strict mode.",
			},
			{
				QuestionType:       models.QuestionTypeMultipleChoice,
				QuestionText:       "Which statements about JavaScript closures are true?",
				Options:            `["Closures have access to outer function variables", "Closures can modify outer function variables", "Closures prevent garbage collection of outer variables"]`,
				AlternativeOptions: `["Closures are created every time a function is called", "Closures are only available in ES6+", "Closures improve performance"]`,
				CorrectAnswers:     `[0, 1, 2]`, // All three are true
				Explanation:        "Closures have access to and can modify outer function variables, and they prevent garbage collection of referenced outer variables. Closures are created when functions are defined, not called, and have been available since early JavaScript versions.",
			},
		},
	}

	if err := db.Create(&practiceQuiz).Error; err != nil {
		logger.Error("Failed to create practice quiz", zap.Error(err))
		return err
	}

	if err := db.Create(&examQuiz).Error; err != nil {
		logger.Error("Failed to create exam quiz", zap.Error(err))
		return err
	}

	if err := db.Create(&mixedQuiz).Error; err != nil {
		logger.Error("Failed to create mixed question types quiz", zap.Error(err))
		return err
	}

	logger.Info("Sample data seeded successfully",
		zap.String("practice_quiz", "Go Fundamentals - Practice"),
		zap.String("exam_quiz", "Python Assessment - Exam"),
	)
	return nil
}
