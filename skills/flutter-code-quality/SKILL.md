---
name: flutter-code-quality
description: Check changed Flutter/Dart files against the opinionated code quality checklist and fix the findings. Use after implementing or changing Flutter code, or when asked to review files for quality.
---

# Flutter Code Quality

An expensive linter: `references/checklist.md` holds rules a static analyzer cannot express (state placement, sealed types, provider shapes, collection idioms, widget extraction). A subagent reads the changed files against the checklist and returns terse `file:line` findings. You, the implementing agent, decide which to apply and make the edits, because you know why the code looks the way it does.

## Scope

The files changed by the current task: `git diff --name-only` plus untracked `.dart` files, or the files the user names. Skip generated files (`*.g.dart`, `*.gr.dart`, `*.freezed.dart`, `lib/generated/`) and tests.

## Running the check

Delegate to the `flutter-code-quality-reviewer` subagent with the file list, through whatever your harness provides for running a named subagent. Without such a subagent, read `references/checklist.md` yourself and review the files against it.

The subagent returns findings grouped by file, each as `path:line - issue → fix`, and `✓ pass` for clean files. It does not edit anything.

## Acting on findings

- Apply a finding unless it conflicts with a project rule in `AGENTS.md`, would change behaviour, or the checklist rule does not fit the situation (for example a `StatefulWidget` the hooks cannot replace). Say which findings you skipped and why, in one line each.
- After edits, rerun code generation if providers or models changed and run `dart analyze`. A second check is only needed when the fixes were large.
- A clean report ends the check; do not look for more.

## Standalone use

When asked to check specific files or a folder outside an implementation task, run the same subagent and present the findings without fixing, unless the user asked for fixes.
