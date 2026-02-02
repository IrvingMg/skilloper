# Quiz Generation Prompt

Use this prompt with LLMs (ChatGPT, Claude, etc.) to generate quizzes from study notes. Copy the entire prompt below, paste your notes at the end, and submit.

---

## The Prompt

```markdown
Convert my study notes into a quiz using JSON format.

## Settings [customize these]

Quiz type: practice
Max options per question: 4
Number of questions: 10-20

## JSON Format

{
  "title": "Quiz Title",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "What protocol operates at the transport layer?",
      "alternative_questions": ["Which protocol works at OSI Layer 4?"],
      "question_type": "single_choice",
      "options": ["HTTP", "TCP", "IP", "Ethernet"],
      "extra_options": ["FTP", "SMTP"],
      "option_variants": [[], ["Transmission Control Protocol"], ["Internet Protocol"], []],
      "answer": ["2"],
      "explanation": "TCP operates at Layer 4 (transport), handling reliable end-to-end delivery."
    },
    {
      "question": "Which are valid HTTP methods?",
      "alternative_questions": ["Which HTTP verbs are part of the standard?"],
      "question_type": "multiple_choice",
      "options": ["GET", "POST", "FETCH", "DELETE"],
      "extra_options": ["QUERY", "SEND"],
      "option_variants": [["Retrieve data"], ["Submit data"], [], ["Remove resource"]],
      "answer": ["1", "2", "4"],
      "explanation": "GET, POST, and DELETE are standard HTTP methods. FETCH is a browser API, not an HTTP method."
    }
  ]
}

### Required Fields

- `question`: The question text
- `question_type`: `"single_choice"` or `"multiple_choice"`
- `options`: Array of answer choices
- `answer`: Array of 1-based index strings
  - Single-choice: exactly one index, e.g., `["2"]`
  - Multi-choice: multiple indices, e.g., `["1", "3", "4"]`
- `explanation`: Why correct answers are correct. Say WHY, don't just restate the answer. Write as standalone text — no references to "the notes" or "the document".

### Variant Fields (add to every question)

- `alternative_questions`: Add 1-2 rephrased versions of the question
- `option_variants`: Add synonyms/expanded forms for options (array of arrays — one per option)
- `extra_options`: Additional wrong answers for shuffling variety

### Other Optional Fields

- `code` + `language`: For code-based questions

## Information Integrity (Critical)

Source fidelity:
- Every fact in questions, options, and explanations must come directly from the notes
- Do NOT infer, assume, or add "common knowledge" — if it's not in the notes, don't include it
- If the notes are ambiguous or incomplete on a topic, skip that topic
- If you're unsure whether something is correct, do NOT include it

Terminology:
- Use technical terms, product names, and acronyms exactly as written in the notes
- Do NOT paraphrase or "simplify" domain-specific terminology

Standalone content (CRITICAL):
- NEVER reference "the notes", "the document", "the section", or "the table" in questions OR explanations
- Write as if from an official exam — no meta-references anywhere
- BAD question: "Which limitations are mentioned in the notes?"
- GOOD question: "Which are limitations of Kubernetes Ingress?"
- BAD explanation: "The notes state that TCP operates at Layer 4."
- GOOD explanation: "TCP operates at Layer 4 (transport), handling reliable delivery."

Wrong options:
- Base wrong options on: logical inversions of stated facts, or alternatives mentioned elsewhere in notes
- Do NOT invent plausible-sounding technical terms or concepts
- Each wrong option must be verifiably wrong based on the notes

## Topic Coverage

Ensure breadth across the notes:
- Cover all major topics, not just the first few
- Don't over-sample one topic while ignoring others
- Include foundational "what is X" AND deeper "how does X work" questions
- Test relationships between concepts, not just isolated facts

## Question Quality

Question stems:
- Test ONE clear concept per question
- Be specific — vague questions lead to arguable answers
- Avoid absolutes ("always", "never") unless the notes explicitly state them
- Avoid trivial questions about minor details

Options:
- Keep all options similar in length and grammatical form
- Randomize correct answer positions (don't cluster them)
- Avoid "all of the above" or "none of the above"

Difficulty:
- Start with foundational concepts, progress to harder questions
- Mix types: recall, comprehension, application, scenario-based

## Multi-Choice Questions

### Vary the Correct Answer Count

For multi-choice questions, vary how many options are correct:
- Some with 2 correct: `"answer": ["1", "3"]`
- Some with 3 correct: `"answer": ["1", "2", "4"]`
- Some with all correct: `"answer": ["1", "2", "3", "4"]`

The key is VARIETY — don't always use the same count.

### Include ALL Correct Answers

CRITICAL: Check every option against the notes.

For each multi-choice question:
1. Write all options first
2. Review EACH option: "Is this correct according to the notes?"
3. Include the index of EVERY correct option in the answer array

Example — Question: "Which are transport layer protocols?"
```
WRONG: options: ["TCP", "UDP", "HTTP", "FTP"], answer: ["1", "2"]
       Problem: Didn't verify HTTP (application) and FTP (application) — got lucky

RIGHT: options: ["TCP", "UDP", "ICMP", "ARP"], answer: ["1", "2"]
       Verified: TCP=correct, UDP=correct, ICMP=wrong (network layer), ARP=wrong (link layer)
```

### When to Use Multi-Choice

- Use when multiple correct answers exist naturally in the notes
- If you cannot find multiple independently correct answers, use single-choice instead
- Each correct answer must be verifiable from the notes

## Variant Generation (Required)

For EVERY question, add:
1. `alternative_questions`: 1-2 rephrased versions of the question
2. `option_variants`: Array with one entry per option — MOST options should have at least one variant

### option_variants: Expand acronyms, reorder words

ALWAYS expand acronyms — this is the most valuable type of variant:

| Acronym | MUST expand to |
|---------|----------------|
| TCP | Transmission Control Protocol |
| UDP | User Datagram Protocol |
| HTTP | HyperText Transfer Protocol |
| HTTPS | HyperText Transfer Protocol Secure |
| TLS | Transport Layer Security |
| gRPC | Google Remote Procedure Call |
| API | Application Programming Interface |
| DNS | Domain Name System |

Other safe transformations:
- Word reorder: "Host-based routing" → "Routing based on host"
- Known abbreviations: "Kubernetes" → "K8s"

Do NOT use interpretive descriptions:
- BAD: "Kubelet" → "Node agent" (interpretation)
- BAD: "Scheduler" → "Pod placer" (invented)
- BAD: "Weighted routing" → "Proportional routing" (different term)

Example:
```
"options": ["TCP", "UDP", "Host-based routing", "Kubelet"],
"option_variants": [
  ["Transmission Control Protocol"],     // Acronym expansion - GOOD
  ["User Datagram Protocol"],            // Acronym expansion - GOOD
  ["Routing based on host"],             // Word reorder - GOOD
  []                                     // No safe variant - use []
]
```

## Final Verification

Before outputting, check:

1. **Source fidelity**: Every fact comes from the notes — nothing invented or assumed
2. **Standalone content**: No question or explanation references "the notes", "the section", or "the table"
3. **Variants present**: `alternative_questions` on every question; acronyms MUST be expanded (TCP, UDP, HTTP, TLS, gRPC, etc.); no interpretive descriptions
4. **Answer completeness**: For multi-choice, verified ALL options and included every correct one
5. **Correct-count variety**: Multi-choice questions have different numbers of correct answers
6. **Topic coverage**: Major topics from notes are represented
7. **Explanations**: Each explains WHY the answer is correct (not just restates it)
8. **Format**: `question_type` matches answer count; indices are 1-based; valid JSON

If any check fails, fix before outputting.

## My Notes

[paste below]
```

---

## Tips for Better Results

### Customizing Settings

Adjust these values at the top of the prompt:
- **Quiz type**: `practice` (immediate feedback) or `exam` (results at end)
- **Max options**: 4 is standard; use 5-6 for harder quizzes
- **Number of questions**: Match your study material depth

### Fixing Common LLM Errors

| Error | Fix |
|-------|-----|
| Added facts not in notes | "Remove any information not explicitly stated in my notes." |
| References "the notes" | "Remove all references to 'the notes', 'the section', 'the table' from questions AND explanations." |
| Missing acronym expansions | "Expand ALL acronyms: TCP, UDP, HTTP, TLS, gRPC, API, DNS. These are required variants." |
| Interpretive variants | "Replace 'Kubelet → Node agent' with [] — that's interpretation, not equivalence." |
| Invented wrong options | "Base wrong options on logical inversions of stated facts, not invented terms." |
| Shallow explanations | "Explain WHY each answer is correct, don't just restate it." |
| Wrong indices (0-based) | "Convert all answer indices to 1-based (first option = 1)" |
| Same correct count on all multi-choice | "Vary the number of correct answers — some with 2, some with 3, some with 4" |
| Missing `question_type` | "Add question_type to every question: single_choice or multiple_choice" |
| Invalid JSON | Paste into a JSON validator and fix manually |
| Variants changed terms | "Do not change technical terms in variants." |

### Iterative Refinement

For best results:
1. Generate initial quiz
2. Import into Skilloper to validate JSON
3. Review questions for accuracy
4. Ask LLM to fix specific issues: "Questions 3 and 7 have incorrect answers. Fix them based on these facts: [paste corrections]"

## See Also

- [Quiz Schema](quiz-schema.md) — Full format specification
- [API Endpoints](api-endpoints.md) — Import endpoints
