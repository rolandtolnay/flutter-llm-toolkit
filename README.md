# flutter-llm-toolkit

> Skills that teach coding agents to write Flutter apps the way an experienced Flutter developer does: Riverpod 3, flutter_hooks, auto_route, proven patterns, and an opinionated code quality check.

## What this is

Seven years of Flutter decisions, distilled into files a coding agent can load. Two skills do the work, a third keeps them growing:

- **`flutter-conventions`** is loaded before implementing or changing Flutter code. Its `SKILL.md` carries the rules that apply to every change (layering, folder placement, widget build structure, action providers, async UX, modern Dart) and routes to about twenty reference files for specific tasks: Riverpod, navigation, auth session, app bootstrap, startup gate, forms, lists and pagination, filters, sheets and dialogs, multi-step wizards, storage, theme, localization, error handling, REST and gRPC API layers, SDK session wrappers, the shared extension kit, and design principles for state and widget APIs.
- **`flutter-code-quality`** runs after implementation as an expensive linter. A read-only subagent (`flutter-code-quality-reviewer`) checks the changed files against `references/checklist.md`, a list of rules a static analyzer cannot express, and returns terse `file:line` findings that the implementing agent then applies.
- **`flutter-capture-pattern`** writes a convention proven in project code back into this repository, so the knowledge base grows from real apps.

The references assume Riverpod with code generation and flutter_hooks. They were extracted from three production apps with gRPC, REST and Firebase backends; the layering is the same for all three.

## Install

Resources install as **copies into the project** (`.agents/skills/`, with `.claude/skills/` symlinks for Claude Code, and the reviewer agent in `.claude/agents/` and `.pi/agents/`). Copies are committed, so teammates and CI see the same files and nothing points at a personal checkout. Paste the prompt below into a fresh session of the coding agent, inside the Flutter project.

<details>
<summary><strong>Install prompt: click to expand</strong></summary>

```text
Install flutter-llm-toolkit into this Flutter project so that Claude Code, Pi and Codex all discover the same skills.

Repository: https://github.com/rolandtolnay/flutter-llm-toolkit.git

## Done when

- `flutter-conventions`, `flutter-code-quality` and (if I chose it) `flutter-capture-pattern` are discoverable by those names in every harness I use, from one set of files.
- The `flutter-code-quality-reviewer` subagent is discoverable in Claude Code and Pi with the model pins from its frontmatter.
- No `{{SKILLS_DIR}}` placeholder remains in any installed file, and every relative reference inside the skills resolves.
- The project `AGENTS.md` has the short Flutter section from `templates/agents-md-flutter-section.md` and no duplicated generic Flutter guidance.

## Establish first

1. Source: use a local checkout if I give you one; otherwise clone to `~/toolkits/flutter-llm-toolkit`.
2. Harnesses: Claude Code, Pi, Codex, or a subset. Ask once if I have not said.
3. Scope: project install is the default. A user-level install (`~/.agents/skills`, `~/.claude/skills`, `~/.pi/agent/skills`) is only for when I say so.
4. Which skills: recommend all three; `flutter-capture-pattern` is optional for projects that never contribute patterns back.

## Layout

- Skills: copy each `skills/<name>/` directory whole into `.agents/skills/<name>/` (Pi and Codex read this location). For Claude Code, create relative symlinks `.claude/skills/<name> -> ../../.agents/skills/<name>`.
- Reviewer agent: copy `agents/flutter-code-quality-reviewer.md` to `.claude/agents/flutter-code-quality-reviewer.md` and `agents/flutter-code-quality-reviewer.pi.md` to `.pi/agents/flutter-code-quality-reviewer.md`. Keep the bodies identical; only the frontmatter differs between the two.
- Replace every `{{SKILLS_DIR}}` in installed files with the installed skills root relative to the project (`.agents/skills`). For a user-level install use the absolute skills root of that harness.
- On a different OS or harness layout, keep the intent (one canonical copy, the others link to it) and tell me what you changed.

## Project instructions

Add the section from `templates/agents-md-flutter-section.md` to the project `AGENTS.md` (create it if missing; Claude Code, Pi and Codex all read `AGENTS.md`). If a `CLAUDE.md` or `AGENTS.md` already contains generic Flutter or Riverpod guidance that the skills now cover, list those sections and ask before removing them; project-specific facts stay.

## Preserve and verify

- Do not overwrite files that are not from this toolkit, or copies carrying local edits, without showing me the diff.
- Do not modify Flutter application code, lint configuration or dependencies. `skills/flutter-conventions/references/analysis_options.yaml` is a sample to compare against, applied only on request.
- Verify by listing the installed skill names as each harness would see them, grepping installed files for `{{SKILLS_DIR}}` and stale checkout paths, and confirming the two agent files have identical bodies.
- Report: what was installed where, symlinks created, placeholder rewrites, anything you could not verify without a new session, and how I invoke each resource.
```

</details>

## Update

Installed copies do not follow the repository. To refresh them:

```text
Update my flutter-llm-toolkit installation in this project. Use the local checkout if I give one, otherwise fetch https://github.com/rolandtolnay/flutter-llm-toolkit.git into ~/toolkits/flutter-llm-toolkit. For each installed skill under .agents/skills and each reviewer agent under .claude/agents and .pi/agents, diff the installed copy against the new source (after replacing {{SKILLS_DIR}} the same way the install did) and show me files with local edits before overwriting them. Keep the .claude/skills symlinks. Verify no placeholder remains and the agent bodies still match. Report what changed.
```

## Uninstall

```text
Remove flutter-llm-toolkit from this project: the .agents/skills directories flutter-conventions, flutter-code-quality and flutter-capture-pattern, the matching .claude/skills symlinks (unlink the symlink entries, never their targets), .claude/agents/flutter-code-quality-reviewer.md, .pi/agents/flutter-code-quality-reviewer.md, and the Flutter skills section in AGENTS.md. Show me the removal list before deleting, skip anything with local edits unless I confirm, and leave everything else untouched.
```

## How it is used

Once installed, nothing needs invoking by hand. The agent loads `flutter-conventions` when it starts Flutter work because the project `AGENTS.md` tells it to, reads the references the task needs, and runs the `flutter-code-quality` check before reporting the change done. You can also ask directly:

```
Check lib/account/ against the code quality checklist
Capture the filter sheet pattern from lib/payment/ into the toolkit
```

## License

[MIT](LICENSE)
