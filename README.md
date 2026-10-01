# flutter-llm-toolkit

> Agents, skills, patterns, and references for Flutter and Dart in Claude Code, with code quality checks, senior review, and project conventions ready to use

## What this is

This extension pack gives Flutter developers three kinds of resources for Claude Code. Skills review and improve Dart code against established quality guidelines. Agents analyze code structure within larger workflows. Reference docs explain your project's patterns so Claude writes code the way you would.

The toolkit is a companion to [llm-toolkit](https://github.com/rolandtolnay/llm-toolkit), which covers general workflows, mental frameworks, and prompt engineering. This toolkit focuses on Flutter and Dart code quality: patterns, anti-patterns, and structural principles that make apps maintainable and easier to change.

The reference docs assume Riverpod and hooks. The review and quality skills work with any state management approach, but some patterns won't apply if you use Bloc or Provider.

## What's included

### Skills

Claude Code activates these skills automatically based on what you're doing.

- `flutter-senior-review` reviews architecture and code structure through 3 core lenses: State Modeling, Responsibility Boundaries, and Abstraction Timing. These lenses are backed by 12 detailed principles.
  - It activates when you review pull requests, audit widget design, evaluate state management, or identify code that's hard to evolve.
- `flutter-code-quality` checks widget organization, folder structure, and common anti-patterns against project conventions.
  - It activates when you restructure folders, fix widget file organization, bring naming into line with conventions, or clean up code after implementation.
- `flutter-code-simplification` reduces complexity without changing behavior. It extracts widgets, flattens logic, and removes unnecessary abstractions.
  - It activates when code is too nested, hard to read, or duplicated.
- `extract-backend-skill` extracts backend patterns into a reusable skill module.
  - Use it to document API infrastructure, error handling, and data layer conventions.

### Agents

These specialized subagents use the Task tool. They can run within milestone workflows or analyze code on their own.

- `ms-flutter-reviewer` analyzes Flutter and Dart code for structural issues. It reports findings by impact (High, Medium, or Low) and does not change code.
- `ms-flutter-code-quality` refactors code to follow quality guidelines. It applies patterns, organizes widgets and folders, simplifies code, and verifies the changes with tests.
- `ms-flutter-simplifier` edits code to make it clearer and easier to maintain while preserving behavior.

### Commands

These slash commands support Flutter-specific workflows.

- `/learn-flutter` analyzes recent code changes and updates the local coding principles file.
  - Use it after implementation work to capture new patterns.
- `/extract-ui-skill` extracts user interface (UI) patterns from the current project into a reusable implement-ui skill.
  - Use it to create portable documentation of widget catalogs, screen patterns, and spacing conventions.
- `/extract-pattern` extracts reusable Flutter and Dart patterns from project code into reference docs.
  - Use it to document any implementation convention in a format optimized for language models.
- `/capture-lesson` records lessons from code refactorings in reusable docs for future sessions.
  - Use it after a refactoring reveals insights that were not obvious.
- `/make-claude-md-flutter` systematically explores a Flutter project to generate a detailed CLAUDE.md.
  - Use it to set up Claude Code instructions for a new or existing Flutter project.

### Reference docs

Claude loads these guides and patterns as context when working in your project.

- `code_quality.md` covers anti-patterns, widget patterns, state management, collections, hooks, themes, and styling.
- `folder_structure.md` covers feature-based organization, screen placement, and subfolder conventions.
- `widget_style_guide.md` covers build method structure, extraction rules, and user experience conventions for asynchronous operations.
- `riverpod.md` covers provider patterns, state management, and Riverpod-specific conventions.
- [`analysis_options.yaml`](references/analysis_options.yaml) is a sample lint configuration based on Merchant App. It uses Very Good Analysis and the native Riverpod lint plugin. Copy or adapt it into your project's root only when requested. Installing reference docs does not change your project's lint configuration. The sample requires `very_good_analysis` and an SDK compatible with native analyzer plugins.
- `patterns/` contains implementation patterns for entity search, error handling, hooks, infinite lists, and localization.
- `skills/rest/` contains a complete REST API skill with Dio infrastructure, mapping between data transfer objects (DTOs) and entities, and error handling patterns.

## Quick start

Copy the prompt below into a fresh session of the coding agent you want to install into. The resources use Claude Code's format. Installing them into another agent requires a guided port; they are not a verified native package for that agent. You do not need an installer script or a Node.js runtime.

<details>
<summary><strong>Install prompt: click to expand</strong></summary>

```text
Install selected resources from flutter-llm-toolkit into the coding agent setup I name.

Repository: https://github.com/rolandtolnay/flutter-llm-toolkit.git

## Goal

A working Flutter/Dart toolkit installation: selected skills, commands, agents, and references are discoverable in each target harness, with their behavior preserved and every local reference resolving from its final location.

## Establish before writing

- Inspect the repository and the target agent's current discovery conventions. Use an existing local checkout if available; otherwise clone to a stable location such as ~/toolkits/flutter-llm-toolkit. Never symlink from a temporary checkout.
- Ask one compact round of questions for decisions I have not already supplied: target harness(es), project or user scope, selected resources, and copy or symlink mode. Confirm the exact set and destinations before writing.
- Present resources by use case: code quality and simplification, architectural review, learning and extraction, project instructions, and REST/pattern references. Recommend a small starting set rather than installing everything by default.
- Recommend copy for project/team sharing, resources requiring adaptation, and systems where symlinks are impractical. Recommend symlinks for personal installs that should follow a stable checkout. Detect OS limitations rather than assuming symlinks work.

## Install and adapt

- Install whole skill directories, including bundled references and principles. Treat references/skills/rest/ as a complete skill when selected, not just a standalone reference file.
- In Claude Code, skills/, commands/, agents/, and references/ normally map to .claude/ or ~/.claude/ counterparts. For other harnesses, use their actual conventions and translate frontmatter, tool names, slash commands, and subagent calls as needed. Report resources that cannot be faithfully adapted instead of installing a non-working approximation.
- Resolve dependencies for the selected resources. flutter-code-quality, ms-flutter-code-quality, and learn-flutter need references/code_quality.md. ms-flutter-reviewer needs the principles bundled with flutter-senior-review. Extraction workflows reference an external create-skill capability; map it to an available equivalent or report it as unmet.
- Inspect every selected resource for hardcoded paths, including project .claude/references paths and ~/.claude/skills/flutter-senior-review/principles/. Ensure they resolve for the chosen scope and harness. Rewrite installed copies when needed; never edit a shared source checkout through a symlink. Use a copy for resources that cannot work unchanged through a symlink, and report that exception.
- Explain that learn-flutter writes to its installed code_quality.md reference: with a symlink, this changes the shared toolkit for every linked project. Confirm whether I want a shared reference or a project-local copy before installing that workflow.
- Keep references/analysis_options.yaml as sample documentation unless I explicitly request applying it. Applying it requires checking the project's Dart SDK and lint dependencies and proposing a merge, not replacing the project's configuration silently.
- Preserve unmanaged files and local edits. Show the diff or removal list and get approval before any overwrite, mode conversion that replaces existing files, or orphan removal. Ask separately before installing system packages or changing project dependencies/configuration.
- Record source checkout and revision, selected resources, actual destination paths, copy/symlink mode per resource, adaptations, and checksums for copies in a small destination-local manifest. If an older installation manifest exists, reconcile it with the actual files and symlinks; do not assume every recorded path is owned or safe to delete.

## Verify and stop

- Check final reference paths and symlink targets, bundled files, resource discovery and invocation names, and unmet dependencies. Search installed resources for stale checkout paths and wrong-harness references. Report any discovery check that requires a new agent session rather than claiming it passed.
- Finish with what works where, how I invoke it, adaptations made, checks performed, and anything blocked. Do not modify Flutter application code, make external writes, or commit changes as an installation test.
- Stop once the confirmed resources are installed and verified, or explain the specific decision or missing capability blocking completion.
```

</details>

The installing agent manages resource selection, dependencies, conflicts, and path adaptation on your machine. The Claude Code examples below use slash syntax. Other agents may use different invocation names.

## Usage examples

**Get a senior-level code review:**

```
Review the recent changes for structural issues
```

Claude reviews the code through 3 lenses: State Modeling, Responsibility Boundaries, and Abstraction Timing. It reports findings by impact level and suggests concrete refactorings.

**Check code against quality guidelines:**

```
Check lib/features/account/ for code quality issues
```

Claude fetches the latest guidelines and checks for anti-patterns, including useState for loading, hardcoded colors, and deep directories. It reports findings in a terse `file:line` format.

**Generate a CLAUDE.md for your Flutter project:**

```
/make-claude-md-flutter
```

Claude examines your codebase's dependencies, architecture, patterns, and naming conventions. It then generates project instructions so future sessions understand your app from the start.

## Updating

Resources installed through symlinks follow changes in their stable checkout. Copied or adapted resources need to be refreshed. Paste this prompt into your agent and name the target setup if it is not already clear:

```text
Update my flutter-llm-toolkit installation using its README install guidance and local manifest. Confirm the target harness and scope. Inspect the recorded checkout and preserve uncommitted source changes before fetching updates. Compare installed copies against recorded checksums and the new source revision, preserve local edits, and show proposed overwrites or removals for approval. Reconcile existing symlinks with the actual filesystem; never write or delete through them into the source checkout. Refresh only selected resources, update the manifest, and verify references and discovery again. Report what changed and anything blocked.
```

Existing installations keep working without reinstalling. If an installation predates the guided prompt, the agent should reconcile its existing manifest with the filesystem before recording new metadata.

## Uninstalling

Paste this prompt into your agent and specify the project or user installation you want to remove:

```text
Remove my flutter-llm-toolkit installation from the harness and scope I confirm. Inspect the local manifest and actual filesystem, then show the exact removal list for approval. Preserve unrelated files, local edits, and the source checkout; if ownership is uncertain, ask rather than delete. Remove installed symlinks themselves, never files inside their targets. For skill-directory symlinks, unlink the directory entry and skip every descendant during deletion and cleanup. This applies to links through shared .agents directories too. For real copied directories, remove only confirmed toolkit-owned files, with separate approval for modified copies. Remove installation metadata only after cleanup succeeds, leave the source checkout intact, and verify that other resources and installations still resolve.
```

## License

[MIT](LICENSE)
