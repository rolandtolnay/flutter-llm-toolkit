# flutter-llm-toolkit

> Flutter/Dart agents, skills, patterns, and references for Claude Code — code quality, senior review, and project conventions out of the box

## What This Is

A curated extension pack for Flutter developers using Claude Code. It provides three things: skills that review and improve your Dart code against established quality guidelines, agents that run structural analysis as part of larger workflows, and reference docs that teach Claude your project's patterns so it writes code the way you would.

Built as a companion to [llm-toolkit](https://github.com/rolandtolnay/llm-toolkit). Where llm-toolkit covers general workflows, mental frameworks, and prompt engineering, this toolkit focuses specifically on Flutter/Dart code quality — the patterns, anti-patterns, and structural principles that separate maintainable Flutter apps from ones that fight you on every change. Reference docs assume Riverpod and hooks — the review and quality skills work with any state management approach, but some patterns won't apply if you use Bloc or Provider.

## What's Included

### Skills

Modular capabilities that Claude Code activates automatically based on what you're doing.

- **`flutter-senior-review`** — Review code for architectural and structural design issues using 3 core lenses (State Modeling, Responsibility Boundaries, Abstraction Timing) backed by 12 detailed principles.
  - Activates when: reviewing PRs, auditing widget design, evaluating state management, or identifying code that's hard to evolve.
- **`flutter-code-quality`** — Check code against project conventions for widget organization, folder structure, and common anti-patterns.
  - Activates when: restructuring folders, fixing widget file organization, aligning naming patterns, or cleaning up code post-implementation.
- **`flutter-code-simplification`** — Reduce complexity without changing behavior. Extracts widgets, flattens logic, removes unnecessary abstraction.
  - Activates when: code is too nested, hard to read, or has duplication.

### Agents

Specialized subagents for the Task tool, designed to run as part of milestone workflows or standalone analysis.

- **`ms-flutter-reviewer`** — Analyzes Flutter/Dart code for structural issues. Reports findings organized by impact (High/Medium/Low) — does not make changes.
- **`ms-flutter-code-quality`** — Refactors code to follow quality guidelines. Applies patterns, widget organization, folder structure, and simplification. Verifies with tests.
- **`ms-flutter-simplifier`** — Simplifies code for clarity and maintainability. Makes edits that improve readability while preserving behavior.

### Commands

Slash commands for Flutter-specific workflows.

- **`/learn-flutter`** — Analyze recent code changes and update the local coding principles file.
  - Use when: after completing implementation work, to capture new patterns.
- **`/extract-ui-skill`** — Extract UI patterns from the current project into a reusable implement-ui skill.
  - Use when: capturing widget catalogs, screen patterns, and spacing conventions as portable documentation.
- **`/extract-backend-skill`** — Extract backend patterns into a reusable CDN-ready module.
  - Use when: documenting API infrastructure, error handling, and data layer conventions.
- **`/extract-pattern`** — Pull reusable Flutter/Dart patterns from project code into reference docs.
  - Use when: capturing any implementation convention as LLM-optimized documentation.
- **`/capture-lesson`** — Capture lessons from code refactorings into reusable docs for future sessions.
  - Use when: after completing a refactoring that revealed non-obvious insights.
- **`/make-claude-md-flutter`** — Generate a comprehensive CLAUDE.md for a Flutter project through systematic discovery.
  - Use when: setting up Claude Code instructions for a new or existing Flutter project.

### Reference Docs

Guides and patterns that Claude loads as context when working in your project.

- **`code_quality.md`** — Anti-patterns, widget patterns, state management, collections, hooks, theme/styling.
- **`folder_structure.md`** — Feature-based organization, screen placement, subfolder conventions.
- **`widget_style_guide.md`** — Build method structure, extraction rules, async UX conventions.
- **`riverpod.md`** — Provider patterns, state management, and Riverpod-specific conventions.
- **`patterns/`** — Implementation patterns for common features: entity search, error handling, hooks, infinite lists, localization.
- **`skills/rest/`** — Complete REST API skill with Dio infrastructure, DTO/entity mapping, and error handling patterns.

## Quick Start

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and Node.js.

**1. Clone the toolkit** (once, anywhere you like):

```bash
git clone https://github.com/rolandtolnay/flutter-llm-toolkit.git ~/toolkits/flutter-llm-toolkit
```

**2. Install into your Flutter project:**

```bash
cd your-flutter-project
~/toolkits/flutter-llm-toolkit/install.js
```

This creates symlinks in `.claude/` pointing back to the toolkit. When you `git pull` in the toolkit repo, all your projects pick up changes automatically.

**Project scope** (default) installs into the current project's `.claude/` — use this when you want per-project control. **Global scope** installs into `~/.claude/` so all projects share the same toolkit:

```bash
~/toolkits/flutter-llm-toolkit/install.js --global
```

<details>
<summary>Copy mode (for checking into project git)</summary>

If you want to commit the toolkit files into your project's repository for team sharing:

```bash
cd your-flutter-project
~/toolkits/flutter-llm-toolkit/install.js --copy
```

This copies files instead of symlinking. You won't get automatic updates — re-run the command to pull in new versions.

If any copied files have local modifications, the installer prompts you to overwrite or keep each one. Use `--force` to overwrite all without prompting.

</details>

<details>
<summary>Windows</summary>

Symlinks require admin privileges on Windows. Use copy mode instead:

```bash
node install.js --copy
```

</details>

After installation, open Claude Code in your Flutter project. Skills activate automatically when relevant — ask for a code review and `flutter-senior-review` kicks in. Commands are available directly (e.g., `/learn-flutter`).

## Usage Examples

**Get a senior-level code review:**

```
Review the recent changes for structural issues
```

Claude applies 3 lenses — State Modeling, Responsibility Boundaries, Abstraction Timing — and reports findings by impact level, with concrete refactoring suggestions.

**Check code against quality guidelines:**

```
Check lib/features/account/ for code quality issues
```

Claude fetches the latest guidelines, scans for anti-patterns (useState for loading, hardcoded colors, deep directories, etc.), and reports findings in terse `file:line` format.

**Generate a CLAUDE.md for your Flutter project:**

```
/make-claude-md-flutter
```

Claude explores your codebase — dependencies, architecture, patterns, naming conventions — and generates project instructions so future sessions understand your app from the start.

## Updating

**Symlink mode** (default): pull the latest in the toolkit repo. All linked projects update immediately.

```bash
cd ~/toolkits/flutter-llm-toolkit
git pull
```

**Copy mode**: re-run the installer to copy updated files. Modified local copies are preserved unless you pass `--force`.

```bash
cd your-flutter-project
~/toolkits/flutter-llm-toolkit/install.js --copy
```

Files removed from the toolkit are cleaned up automatically on the next install run.

## Uninstalling

Remove all toolkit files from a project or global scope:

```bash
cd your-flutter-project
~/toolkits/flutter-llm-toolkit/install.js --uninstall
```

```bash
~/toolkits/flutter-llm-toolkit/install.js --uninstall --global
```

This removes only files the toolkit installed — your own `.claude/` files are untouched.

## License

[MIT](LICENSE)
