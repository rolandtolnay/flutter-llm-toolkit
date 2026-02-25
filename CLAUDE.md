# flutter-llm-toolkit

Flutter/Dart agents, skills, patterns, and references for Claude Code.

## Distribution

Installed by cloning the repo and running `install.js`. The installer symlinks (default) or copies (`--copy`) files into `.claude/` (project, default) or `~/.claude/` (global via `--global`).

## Repository Structure

| Directory | Installs to | Contents |
|-----------|-------------|----------|
| `agents/` | `~/.claude/agents/` | Flutter-specific subagent definitions |
| `commands/` | `~/.claude/commands/` | Slash commands for Flutter workflows |
| `skills/` | `~/.claude/skills/` | Claude Code skills (SKILL.md + supporting files) |
| `references/` | `~/.claude/references/` | Code quality guides, patterns, widget conventions |

## Development

Changes made here are testable immediately via `./install.js --global` (symlinks into `~/.claude/`).
