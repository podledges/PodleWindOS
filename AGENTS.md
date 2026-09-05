# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- This is **PodleWindOS**, the Windows/main-OS side of the localhost Port NixVM data pipeline. Tools here run at Windows OS-access level; v1 actions are read-only diagnostics only.
- For `wind`, `windOS`, or `main system`, consult [`./WinSpec/`](./WinSpec/) only when sentence context clearly refers to the Windows/main machine. Matching is case-insensitive and ignores trailing spaces and periods; do not load it for bare `OS`, `Mix`, or `Next`.
- Captain-facing runbook for the loopback RX/TX hooks is [`./README.md`](./README.md).
- `docs/PromptHistory.md` is intentionally git-ignored. Process that file's contents **if and only if** the ingesting agent is configured for `xhigh` difficulty, or the input contains `look at the logs`, `review history`, `project history`, or `prompt history`.
- Keep technical context short and avoid letting OS details dominate chat.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
