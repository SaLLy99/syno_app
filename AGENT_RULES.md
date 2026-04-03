# AGENT_RULES.md

## Local Repository Rules

- Do not edit unrelated files.
- Minimize diff size.
- Preserve current behavior unless the task explicitly changes it.
- Prefer modifying existing code over introducing new abstractions.
- If introducing a new helper/class/function, explain why existing structure is insufficient.
- If tests exist in the touched area, update or add tests when appropriate.
- Do not remove unused code automatically; list it separately.
- Do not rewrite working code for style alone.
- Do not change naming conventions unless required by the task.
- If the task affects API contracts, DTOs, DB schema, external integrations, or auth flow, call it out before implementation.