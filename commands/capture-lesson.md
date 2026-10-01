---
description: Capture lessons from implementation work into reusable docs for future LLM code writers. Use after a refactoring, or mid-conversation to capture insights from the current session.
argument-hint: [topic-hint] [commit_sha] (empty = derive from conversation)
allowed-tools: [AskUserQuestion, Bash, Read, Grep, Glob, Write]
---

<objective>
Distill lessons from implementation work into a standalone reference file. The command (an LLM) derives lessons from one of two sources:

1. **Diff analysis** — when arguments or git state point to specific code changes
2. **Conversation context** — when invoked mid-conversation after implementation work, the conversation itself (decisions made, problems hit, patterns discovered, approaches debated) is the primary source

Output: a `.md` file in `etc/lessons/` optimized for LLM consumption with enough clarity for human review.

A lesson sits between one-liner code quality rules and comprehensive playbooks. It captures the "why" and "watch out for" from a specific piece of work — typically 2-4 insights with code examples.
</objective>

<context>
Refactoring description: $ARGUMENTS (may be empty if invoked mid-conversation with prior context)

Git state:
!`git status --porcelain | head -20`
!`git diff --stat | tail -5`
</context>

<developer_role>
**Diff mode:** The developer spotted a problem and gave direction — they did NOT author line changes. Ask about: what looked wrong (the trigger), high-level direction, whether the result is satisfactory. Do NOT ask about: why specific code patterns were chosen, trade-offs between approaches — derive these from the diff.

**Conversation mode:** The developer has been an active participant — their messages describing problems, evaluating approaches, and reacting to results ARE primary evidence. Mine the conversation for: what surprised them, what they corrected, what they explicitly called out as important. Do NOT re-ask questions the conversation already answers.
</developer_role>

<output_format_spec>
Lesson files are optimized for LLM consumption — terse, actionable, with concrete code.

**Structure template:**
```markdown
# Lesson: Descriptive Title

One-line scope: what was refactored, what was wrong with the old approach.

**Domain:** state-management | navigation | error-handling | data-layer | ui-structure | api-design | database | concurrency | auth | caching | forms | testing | etc.
**Applies when:** concrete trigger condition for when this lesson is relevant

## [Insight Title]

1-2 sentences: what the transformation is and what's non-obvious about it. Reference `specific classes` and `patterns`.

```
// Before: brief label
oldApproach();

// After: brief label
newApproach();
```

## [Another Insight]

...

## Rules

- Terse one-liner with `inline code` (distilled from insights above)
- Transformation: `old_pattern` → `new_pattern`

## Anti-Patterns (flag these)

- Bad pattern (`concrete.bad.code()`) → fix
- Pitfall: situation that causes subtle bugs → what to do instead
```

**Sizing:** A typical lesson file is 40-70 lines. 2-4 insight sections, 3-6 rules, 3-6 anti-patterns.
</output_format_spec>

<context_efficiency>
Write the lesson file directly — user reviews in their editor or via `git diff`.

- No "present draft in conversation" step — write the file, then ask for feedback
- Iterate via targeted edits, not full rewrites
</context_efficiency>

<process>

## 1. Establish Scope

### 1.1 Assess Available Context

Check three sources for refactoring context, in priority order:
1. **$ARGUMENTS** — explicit description and optional commit SHA
2. **Conversation history** — prior messages describing implementation work, decisions, problems, and outcomes
3. **Git state** — uncommitted changes or recent commits

Parse $ARGUMENTS for a commit SHA (7+ hex chars; verify with `git rev-parse --verify <sha>^{commit}`, treat as description text if verification fails).

### 1.2 Determine Analysis Mode

**Choose the mode based on what's available:**

**→ Diff mode** (use when ANY of these are true):
- $ARGUMENTS contains a commit SHA
- $ARGUMENTS explicitly describes a refactoring to find in git
- There are uncommitted changes or recent commits with no conversation context

**→ Conversation mode** (use when ALL of these are true):
- $ARGUMENTS is empty or contains only a topic hint
- The conversation contains substantive implementation work — code was written, problems were debugged, decisions were made, or approaches were evaluated
- The conversation provides enough context to derive lessons without a diff

When ambiguous, prefer conversation mode if the conversation is rich, diff mode if it's thin. If genuinely unclear, use AskUserQuestion:
```
Question: "What should I capture lessons from?"
Header: "Source"
Options:
- "This conversation" — What we just worked on together
- "Uncommitted changes" — Current work in progress (git diff)
- "Specific commits" — A commit or range (I'll provide refs)
- "All changes on branch" — Everything since branching from main
```

### 1.3 Gather Source Material

**Diff mode — gather changes:**
- Uncommitted: `git diff --cached` and `git diff`
- Specific commits: `git show <commit>` or `git diff <from>..<to>`
- Branch changes: `git diff main...HEAD`
- For large diffs (20+ files), focus on files most relevant to the refactoring description. Skip auto-generated files, lock files, and config churn.

**Conversation mode:** The conversation history is the source material. If the conversation references specific files, read them for concrete code examples to include in the lesson. Proceed to Step 2 for structured analysis.

## 2. Analyze Source Material

### 2.1 Diff mode

**Read the Diff.** Study the full diff. Identify:
- What patterns were replaced and with what
- Structural changes (file moves, class splits, inheritance changes)
- New abstractions introduced or old ones removed
- Error handling, state management, or API changes

**Read Changed Files for Full Context.** The diff shows deltas but not surrounding code. Read the current state of the 3-5 most significant changed files — prioritize:
- Files demonstrating the new pattern most clearly
- Files with the largest logical changes
- Files that had the most issues in the old approach

Use Grep/Glob to find related files if the diff references patterns, base classes, or utilities not in the changeset.

### 2.2 Conversation mode

**Reconstruct the narrative.** Scan the conversation chronologically and identify:
- The starting problem or goal
- Problems encountered and how they were solved
- Incorrect approaches that were tried and abandoned (and why)
- Decisions between alternatives (what was chosen and what was rejected)
- The turning point — what unlocked the solution
- The final approach and why it won

**Extract concrete evidence.** For each potential insight, find supporting material:
- Code snippets from the conversation (before/after if available)
- If the conversation references files that were modified, read those files for current-state code examples
- Developer statements that validate the insight ("that's the key thing", corrections, emphatic reactions)
- Explicit signal phrases: "the key insight is...", "the problem was...", "don't do X because..."

**Verify with codebase.** If lessons reference patterns or files, use Grep/Glob/Read to confirm the code matches what was discussed. Pull concrete code examples from the actual files — don't rely solely on conversation snippets which may be outdated or partial.

## 3. Derive Lessons

This is the core step. Regardless of mode, derive:

- **Insights**: What was the core improvement or discovery? What's non-obvious? What would an LLM get wrong without this knowledge?
- **Rules**: Terse distillation for quick LLM reference
- **Anti-patterns**: What does the "bad" version look like? What pitfalls would an LLM fall into?
- **Trigger condition**: When should a future LLM apply these lessons?

**Diff mode:** Analyze the before→after transformation. The diff is the primary evidence.

**Conversation mode:** Synthesize across the full conversation arc. Prioritize:
1. Insights the developer explicitly called out or reacted strongly to
2. Dead ends that wasted time — the "don't do this" is often the most valuable lesson
3. Non-obvious connections discovered during the work (e.g., "the real problem was X, not Y")
4. Patterns that emerged as the right approach after trying alternatives

Assign a **domain tag** matching the primary area of the work.

Derive the filename slug from $ARGUMENTS, conversation context, or the dominant theme (lowercase, hyphens, max 4-5 words).

## 4. Validate with Developer

Before writing the file, briefly present the proposed lessons in conversation — list each insight as a one-liner. Use AskUserQuestion:

```
Question: "I derived these lessons from the changes. Anything off or missing?"
Header: "Validate"
Options:
1. "Looks right" — Write the file
2. "Missing something" — I'll describe what's missing
3. "Something's wrong" — I'll point out what's off
```

## 5. Write Lesson File

Create `etc/lessons/` directory if it doesn't exist:
```bash
mkdir -p docs/lessons
```

Write directly to `etc/lessons/{slug}.md`.

Report: file path, line count, number of insights, domain tag.

## 6. Review

Use AskUserQuestion:
```
Question: "Lesson file written. Review in your editor — what's next?"
Header: "Review"
Options:
1. "Looks good" — Done
2. "Needs adjustments" — I'll describe what to change
3. "Too verbose" — Compress further
```

Apply targeted edits if changes needed.

</process>

<success_criteria>
- Lessons derived by the command (from diff or conversation), not dictated by the developer
- Developer validates direction (trigger, completeness) — not asked to explain what the command can derive
- "Applies when" trigger present and specific enough for future injection
- Insights are 1-2 sentences with `inline code` + before/after code blocks (code examples from diff or from files referenced in conversation)
- Rules section has terse one-liners mechanically extractable for skill synthesis
- Anti-patterns section merges pitfalls and bad patterns with concrete code
- Conversation mode: dead ends and corrections captured as anti-patterns, not just the final approach
</success_criteria>
