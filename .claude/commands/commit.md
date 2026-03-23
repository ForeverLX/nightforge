Generate a conventional commit message for the current staged changes.

Rules:
- Format: `type: subject`
- Type: feat | fix | docs | refactor
- Subject: imperative mood, no period, under 72 characters
- No em-dashes anywhere
- If changes span multiple concerns, suggest splitting into separate commits
- Show the staged diff first so Darrius can verify before the message is used
- Never run git push — stage only, Darrius pushes manually

Run: `git diff --staged` and generate the commit message from the actual diff.
