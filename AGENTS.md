# flutter-llm-toolkit

Skills and a reviewer subagent that teach coding agents how one experienced Flutter developer builds apps with Riverpod, flutter_hooks and auto_route. Installed by pasting the README prompt into the target agent; there is no installer script.

## Layout

| Path | Purpose |
|------|---------|
| `skills/flutter-conventions/` | Loaded before implementing Flutter code. `SKILL.md` is the always-needed rules plus a routing table; `references/` holds one file per topic. |
| `skills/flutter-code-quality/` | The expensive-linter workflow. `references/checklist.md` is the rule list the reviewer applies. |
| `skills/flutter-capture-pattern/` | Writes new knowledge back into this repo from project code. |
| `agents/flutter-code-quality-reviewer.md` | Read-only reviewer for Claude Code (`model: opus`, `effort: medium`). |
| `agents/flutter-code-quality-reviewer.pi.md` | Same body with Pi frontmatter (`openai-codex/gpt-6.1-sol`, `thinking: medium`). |
| `templates/` | Snippets the install prompt copies into a project, such as the `AGENTS.md` section. |

Both agent files must keep identical bodies; only the frontmatter differs. Paths inside agent bodies use the `{{SKILLS_DIR}}` placeholder, which the install prompt replaces with the installed skills root.

## Writing rules

The reader is a frontier coding model that knows Flutter and Riverpod. Document the shapes this developer has settled on, the decisions they encode and what callers do; leave out what the model already knows.

- Reference files: H1, one-line scope, H2 sections, code blocks carry the content, optional closing `## Anti-Patterns (flag these)`, a `Sources:` line naming project and file paths. 60–150 lines; `rest_api.md`, `common_kit.md` and `lists.md` may run longer because their code is the content.
- State each rule once. Absolutes only for real invariants (layer boundaries, proto types staying in `domain/`); everything else is a decision rule.
- No step-by-step scripts, no repeated warnings, no "why it matters" lists. One clause of reason where the rule is not self-evident.
- Code is Riverpod 3 codegen syntax, generic names (`Item`, `Order`), real signatures for shared helpers, trimmed to the shape.
- `checklist.md` is the exception: it is a lint list, so it names specific bad and good forms, grouped by section, with the anti-pattern list at the end as the reviewer's scanning list.
- Skill descriptions stay one or two sentences stating when to load the skill, nothing more.
- Testing guidance is out of scope for this toolkit.

## Sources

Patterns come from three apps: merchant-app (gRPC, auto_route, Riverpod 3; canonical where apps differ), boardbit (Firebase, Riverpod 2, largest feature set) and forgeblast_app (REST over Dio, auto_route, Riverpod 3). When adding or revising a reference, read the implementation in the source app rather than paraphrasing an older doc, and document the convention rather than a deviation found in older code.

## Validating changes

Install into a Flutter project with the README prompt (copy mode into `.agents/skills/`), then confirm the skills are discoverable by name, `{{SKILLS_DIR}}` no longer appears in installed files, and the reviewer subagent returns findings on a known file. For a wording change in a reference, reading the file as the target model would is enough.
