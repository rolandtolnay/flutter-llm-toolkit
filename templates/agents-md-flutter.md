# AGENTS.md for a Flutter project

The project `AGENTS.md` is loaded into every conversation, so it carries only what the agent cannot get elsewhere: the skills pointer below, and project facts not derivable from the code or the skills. Generic Flutter, Riverpod and widget guidance lives in the skills and is not repeated.

## Required section

Paste after installing the skills:

```markdown
## Flutter skills

Load `flutter-conventions` before implementing or changing Flutter code; it holds the architecture, widget and Riverpod conventions and routes to deeper references per task. Load `flutter-testing` when writing or changing tests. Before reporting a Flutter change as done, run the `flutter-code-quality` check on the changed files and apply its findings.
```

## Sections most Flutter projects need

Each is a few lines. State the fact and the reason; leave out steps the agent can work out.

- **What the app is.** One line: the product, who uses it, and what to optimise for ("a payments app serving real merchants; prefer reliability over cleverness").
- **Commands.** The version manager and the commands that differ from the defaults: `fvm flutter` instead of `flutter`, the code generation command, the localization script, how to run and test. Say which command follows which kind of change, not a sequence to run every time.
- **Backend boundary.** Which transport types exist (proto messages, JSON models, Firestore documents), where they are generated, and that they stay inside `domain/`. Naming the generated package path lets the reviewer catch leaks.
- **Environments.** The flavor names, which distinction the code actually branches on (production versus everything else), and how variants are named.
- **Product rules the code must honour.** Behaviour a model would not infer: how unknown backend values render, which brands or locales ship, which screens must deep-link.
- **Scope rules.** What is best effort (small screens, large text, dormant brands) and what is not, so a failing edge case does not pull the agent into out-of-scope fixes.
- **Things that look wrong but are not.** Dormant code kept on purpose, lint rules disabled for a reason, legacy modules not worth migrating.
- **Boundaries.** What the agent may do without asking (edit in-scope code, run codegen, analyze and tests) and what needs confirmation (dependency or lint changes, regenerating protos, anything touching release configuration). State it once.
- **Test facts.** The sandbox account an agent signs in with for live checks, and anything about the suite the skill cannot know: a support library living somewhere other than `test/support/`, flows that must stay covered by a routed journey.
- **Project skills.** One line per project-specific skill and when to load it.

## What earns a line

Add a line when one of these holds, and drop it once the agent no longer needs it:

- The agent got something wrong, you corrected it, and the same correction would apply again. Record the rule and its reason, not the incident.
- A fact lives only in your head or in a conversation: a product decision, a deadline-driven compromise, a backend quirk.
- The code can be read two ways and only one is right (environments that behave the same, dead-looking code that is not dead).
- A check the agent cannot derive, such as the exact codegen or localization command.

Leave out what the agent already does well: generic Flutter and Riverpod guidance (the skills cover it), anything readable from `pubspec.yaml` or the folder layout, step-by-step scripts, and reminders to run tests or format code. Reread the file when the model generation changes; instructions written to steer an older model tend to over-constrain a newer one.
