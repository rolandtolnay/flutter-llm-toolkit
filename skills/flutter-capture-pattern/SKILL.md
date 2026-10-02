---
name: flutter-capture-pattern
description: Record a Flutter convention or pattern proven in project code as a reference in the flutter-llm-toolkit. Use when asked to capture, document or extract a pattern into the toolkit.
---

# Capture a Flutter Pattern

Turn something proven in a project into toolkit knowledge: a new reference file in `flutter-conventions/references/`, an addition to an existing one, or a new rule in the `flutter-code-quality` checklist. The toolkit is the single source; project copies are refreshed from it with the README update prompt.

## Where the toolkit lives

Write to a checkout of the toolkit repository, not to a project's installed copy. The README install prompt clones to `~/toolkits/flutter-llm-toolkit`; if no checkout is known, ask where it is. Read the toolkit's `AGENTS.md` for the writing rules before drafting.

## What qualifies

A pattern earns a place when it recurs across features or apps, a model would not produce it unguided, and the source code demonstrates it working. One-off product logic, unfinished code and project-specific configuration do not. If the candidate is a single lint-like rule with a clear bad and good form, it belongs in the checklist under the matching section rather than in a reference.

## Working from source

Read the implementation the pattern comes from, not a description of it. Generalise names, trim product fields and logging, keep real signatures of shared helpers, and name files by their place in the layout (`lib/common/util/debouncer.dart`) rather than by the project they came from. Where the code deviates from its own convention, document the convention and say nothing about the deviation. When the pattern overlaps an existing reference, extend that file instead of creating a neighbour, and update the "Where to Look" table in `flutter-conventions/SKILL.md` only when a new file was added.

## Done when

- The reference follows the format of its neighbours (H1, one-line scope, H2 sections, code carries the content, optional closing Anti-Patterns).
- No project names, repository paths or developer-specific setup appear; the toolkit is used by people without access to the source project.
- Every rule appears once; no absolutes except real invariants; no process scripts.
- A reader with the file alone could reproduce the pattern in a new app.
- You report the file path, what was added, and whether the project copy needs refreshing.
