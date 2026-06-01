# Eval results — Research Copilot

_Generated: 2026-06-01T09:07:44Z_  
_Runtime: 17.2s over 10 golden questions_

## Headline numbers

| Metric | Value |
|---|---|
| Retrieval hit-rate @ k=5 | **100.0%** |
| Groundedness (gpt-4o-mini judge) avg | **76.0/100** |
| Citation accuracy (verbatim quote match) | **100.0%** (26/26) |

## Per-question detail

| # | Question | Hit@5 | Groundedness | Citations (correct/total) |
|---|---|---|---|---|
| 1 | What made the bank connection step difficult for users? | ✅ | 70/100 | 3/3 |
| 2 | Why did some users feel overwhelmed during signup? | ✅ | 70/100 | 3/3 |
| 3 | What did users suggest would have made onboarding easier? | ✅ | 70/100 | 3/3 |
| 4 | Did any users almost abandon the product during onboarding? | ✅ | 70/100 | 3/3 |
| 5 | What did the Beta Health user say about the dashboard after signup? | ✅ | 90/100 | 2/2 |
| 6 | How did the Crate trial signup feel to the user? | ✅ | 90/100 | 2/2 |
| 7 | Did users mention security concerns during signup? | ✅ | 70/100 | 3/3 |
| 8 | What did Hassan want instead of being forced to connect integrations? | ✅ | 80/100 | 2/2 |
| 9 | Did users come back to the product after initially closing it? | ✅ | 70/100 | 2/2 |
| 10 | What made the Crate trial feel like a long implementation instead of a quick try? | ✅ | 80/100 | 3/3 |

## Methodology

- **Retrieval hit-rate @ k=5**: fraction of golden questions where at least one expected
  snippet (verbatim substring) appears in the top-5 chunks returned by pgvector cosine search.
- **Groundedness**: a separate gpt-4o-mini call scores each answer 0-100 against the chunks
  it cited, penalizing any unsupported claim. The judge is not the same model that generated
  the answer, reducing self-confirmation bias.
- **Citation accuracy**: fraction of citations across all answers where the cited `quote`
  is a verbatim substring of the cited chunk's text. Hallucinated quotes fail this check.
- Golden set lives in [`evals/golden_set.yml`](golden_set.yml).
