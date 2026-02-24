# flutter-llm-toolkit

Flutter/Dart agents, skills, patterns, and references for Claude Code.

## Distribution

Installed via `npx flutter-llm-toolkit`. The installer (`install.js`) copies or symlinks files into `~/.claude/` (global) or `.claude/` (local).

## Repository Structure

| Directory | Installs to | Contents |
|-----------|-------------|----------|
| `agents/` | `~/.claude/agents/` | Flutter-specific subagent definitions |
| `commands/` | `~/.claude/commands/` | Slash commands for Flutter workflows |
| `skills/` | `~/.claude/skills/` | Claude Code skills (SKILL.md + supporting files) |
| `references/` | `~/.claude/references/` | Code quality guides, patterns, widget conventions |

## Development

Changes made here are testable immediately via `node install.js --global --link` (symlinks into `~/.claude/`).
