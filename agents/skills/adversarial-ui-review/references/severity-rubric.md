# Severity Rubric (adversarial UI review)

Aligned with Nielsen 0–4 practice and Astralab evidence scoring.

| Label | Meaning | Gate impact | Score |
|---|---|---|---|
| **Blocker** | WCAG A/AA failure, locks users out, data loss, unusable primary task | Fail gate | −12 |
| **Critical** | Measurable task failure for many users; broken empty/error/loading; focus trap | Fail gate | −8 |
| **Warning** | Visible friction; inconsistent density/spacing; weak hierarchy | Does not fail alone | −4 |
| **Tip** | Polish | Informational | −1 |

**Gate**: `VERDICT: APPROVED` only if zero Blockers and zero Criticals.

**Score** (optional): `100 − Σ impacts`. Track direction across iterations; do not bike-shed ±1 Tips.
