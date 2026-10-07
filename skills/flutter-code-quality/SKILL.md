---
name: flutter-code-quality
description: Review changed Flutter/Dart files against the Flutter conventions, testing guidance and code quality checklist, then fix the findings. Use after implementing or changing Flutter code, or when asked to review files for quality.
---

# Flutter Code Quality

A read-only subagent reads the changed files against `flutter-conventions`, `flutter-testing` and `references/checklist.md` (rules a static analyzer cannot express: state placement, sealed types, provider shapes, collection idioms, widget extraction, test layering) and returns terse `file:line` findings. You, the implementing agent, decide which to apply and make the edits, because you know why the code looks the way it does.

## Scope

The files changed by the current task: `git diff --name-only` plus untracked `.dart` files, or the files the user names. Skip generated files (`*.g.dart`, `*.gr.dart`, `*.freezed.dart`, `lib/generated/`).

## Running the check

Delegate to the `flutter-code-quality-reviewer` subagent with the file list and the change's intent in a line, through whatever your harness provides for running a named subagent. Without such a subagent, read the same sources yourself and review the files against them.

The subagent returns findings grouped by file, each as `path:line - issue → fix`, naming the source rule when it is not the checklist, and `✓ pass` for clean files. It does not edit anything.

## Acting on findings

- Apply a finding unless it conflicts with a project rule in `AGENTS.md`, would change behaviour, or the rule does not fit the situation (for example a `StatefulWidget` the hooks cannot replace). Say which findings you skipped and why, in one line each.
- After edits, rerun code generation if providers or models changed and run `dart analyze`. A second check is only needed when the fixes were large.
- A clean report ends the check; do not look for more.

## Standalone use

When asked to check specific files or a folder outside an implementation task, run the same subagent and present the findings without fixing, unless the user asked for fixes.
