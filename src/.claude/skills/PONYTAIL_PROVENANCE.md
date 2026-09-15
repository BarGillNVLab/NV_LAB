# ponytail skills

Source: https://github.com/DietrichGebert/ponytail.git (plugin version 4.10.0, MIT)
Installed: skills/ only — the SKILL.md instruction files.

Deliberately NOT installed:

- `hooks/claude-codex-hooks.json` and `hooks/*.js`. They register SessionStart,
  SubagentStart and UserPromptSubmit hooks that run `node` on every session
  start and every prompt. That is persistent code execution in this repo's
  environment; add it yourself if you want it.
- `benchmarks/`. Needs an ANTHROPIC_API_KEY via .env and makes paid API calls.

The skills are plain instruction text. `ponytail-review` reviews diffs for
over-engineering only — it says correctness, security and performance are out
of its scope, so it complements a normal review rather than replacing one.
