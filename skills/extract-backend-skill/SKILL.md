---
name: extract-backend-skill
description: Extract reusable backend patterns from Flutter projects into CDN-ready skill modules. Use when generalizing API infrastructure, error handling, or DTO patterns for cross-project distribution.
allowed-tools: Task(Explore), AskUserQuestion, Glob, Grep, Read, Write, Bash, Skill(create-skill)
---

<objective>
Output directory: `.claude/extraction/backends/`. Extracts API infrastructure, error handling, and DTO patterns as generalized, CDN-ready modules.
</objective>

<process>

## Step 1: Intake

<critical>
BEFORE doing anything else, use AskUserQuestion to present this menu to the user.
Do NOT proceed to analysis until user responds.
</critical>

<intake_question>
Present using AskUserQuestion with these options:

Question: "What would you like to extract from this project?"
Header: "Scope"
Options:
1. "Full backend module" - API client + patterns + error handling + DTOs
2. "Specific components" - Choose which parts to include
3. "Review existing extraction" - Continue from previous session

If user selects "Specific components", follow up asking which categories:
- API Infrastructure (HTTP client, API classes, composition)
- Error Handling (exceptions, mapping, recovery)
- DTO/Entity (serialization, parsing, validation)

If user selects "Review existing extraction":
1. Read `.claude/extraction/analysis.json` and `.claude/extraction/decisions.json`
2. Present previous findings summary and component decisions
3. Use AskUserQuestion to ask which phase to resume from: "Analysis", "User decisions", "Generate output", or "Verification"
4. Jump to that phase
</intake_question>

## Step 2: Parallel Analysis

<parallel_analysis>
<critical>
You MUST send ONE message containing all Task tool calls to achieve parallel execution.
</critical>

Determine which agents to launch based on user's intake selection:
- "Full backend module": Launch all 3 agents
- "Specific components": Launch only agents for selected categories

For each agent to launch, read its prompt file using the Read tool, then use the file content as the Task prompt parameter:

| Category | Prompt file | Task description |
|----------|-------------|------------------|
| API Infrastructure | `references/agent-api-infrastructure.md` | "Analyze API infrastructure patterns" |
| DTO/Entity | `references/agent-dto-entity.md` | "Analyze DTO/entity patterns" |
| Error Handling | `references/agent-error-handling.md` | "Analyze error handling patterns" |

Each Task uses `subagent_type: "Explore"`.

Wait for all agents to complete before proceeding.
</parallel_analysis>

## Step 3: Synthesize and Review

<synthesis>
After all agents complete, combine their findings into a unified analysis:

1. **Parse Agent Outputs**: Extract JSON from each agent's response
2. **Merge Findings**: Combine into single analysis object
3. **Identify Inconsistencies**: Note conflicting patterns or missing pieces
4. **Save Analysis**: Write to `.claude/extraction/analysis.json` using Write tool
</synthesis>

<present_findings>
Present findings to user in this format:

---

**API Infrastructure**

Found: [library] with [key features]
Location: [primary files]

HTTP Client Patterns:
- [Pattern with description]

API Class Patterns:
- [Pattern with description]

Composition Patterns:
- [Pattern with description]

Recommendation: [Include/Exclude] - [reasoning]

---

**DTO/Entity**

Found: [serialization approach]
Location: [primary files]

Patterns detected:
- [Pattern 1 with brief description]
- [Pattern 2 with brief description]

Recommendation: [Include/Exclude] - [reasoning]

---

**Error Handling**

Found: [error types summary]
Location: [primary files]

Patterns detected:
- [Pattern 1 with brief description]
- [Pattern 2 with brief description]

Recommendation: [Include/Exclude] - [reasoning]

---
</present_findings>

<confirm_inconsistencies>
If any inconsistencies or gaps were found during analysis, present them to the user:

"I found some areas that may need clarification:
- [Inconsistency 1: e.g., 'Mixed serialization approaches - both freezed and manual']
- [Gap 1: e.g., 'No error recovery patterns found']

Would you like me to:
1. Proceed with current findings
2. Investigate further with additional analysis"

Use AskUserQuestion to gather their decision.
</confirm_inconsistencies>

<additional_research>
If user requests further research on specific areas:

Use AskUserQuestion to ask:
"Which areas need deeper investigation?"
Options:
- HTTP client configuration details
- API method patterns and pagination
- Error recovery and retry logic
- DTO validation patterns
- Other (specify)

For each selected area, use the Task tool to launch an additional Explore agent with focused prompt:
```
Task(
  description: "Deep dive on [area]",
  subagent_type: "Explore",
  prompt: "Investigate [specific area] in more detail. Look for: [specific patterns]. Return additional patterns found in same JSON format."
)
```

Use the Write tool to merge new findings into the existing analysis.json file.
</additional_research>

## Step 4: Gather User Decisions

<critical>
Use AskUserQuestion to confirm user decisions. Do NOT assume or auto-select.
</critical>

<decision_questions>
Use AskUserQuestion with multiSelect where appropriate:

Question 1: "Which components should be included in the module?"
Header: "Components"
Options: [Based on what was found - e.g., "API Infrastructure", "Error Handling", "DTO/Entity", "All"]
multiSelect: true

Question 2: "What should the module be called?"
Header: "Name"
Options: ["rest", "backend", "api", "Other"]

Question 3: "Any patterns to exclude or modify?"
Header: "Customize"
Options: ["No customizations", "Exclude some patterns", "Modify placeholders"]
</decision_questions>

<save_decisions>
Use the Write tool to save decisions to `.claude/extraction/decisions.json`:

```json
{
  "module_name": "rest",
  "components": {
    "api_infrastructure": {"include": true, "customizations": []},
    "dto_entity": {"include": true, "customizations": []},
    "error_handling": {"include": true, "customizations": []}
  },
  "additional_context": ""
}
```
</save_decisions>

## Step 5: Generate Output

<critical>
Before generating SKILL.md, invoke `Skill('create-skill')` with args containing the module name, included component list from decisions, and analysis summary from `.claude/extraction/analysis.json`.
</critical>

<setup_directories>
Use Bash to create the output directory structure:
```bash
mkdir -p .claude/extraction/backends/{module-name}
mkdir -p .claude/extraction/backends/{module-name}/references
```
</setup_directories>

<generate_skill_md>
Generate SKILL.md following this structure:

```markdown
---
name: {module-name}
description: {one-line description}
---

<overview>
{High-level description}

<patterns_included>
- {Category 1}: {brief description}
- {Category 2}: {brief description}
</patterns_included>

<dependencies>
- {package}: ^{version} ({purpose})
</dependencies>
</overview>

<patterns>
<pattern name="{Category Name}">
<description>{What this pattern does}</description>

<implementation language="dart">
{GENERALIZED code with placeholders}
</implementation>

<rationale>{Why this pattern exists}</rationale>
</pattern>
</patterns>

<examples>
<example name="{Use Case}">
<scenario>{Real-world usage scenario}</scenario>

<usage language="dart">
{Example code}
</usage>

<notes>
- {Key points}
</notes>
</example>
</examples>

<references>
<reference file="references/api-infrastructure.md">{description}</reference>
</references>
```

Use the Write tool to save to: `.claude/extraction/backends/{module-name}/SKILL.md`
</generate_skill_md>

<generate_references>
For each included component, generate a reference file:

**api-infrastructure.md** (if included):
- HTTP client configuration patterns
- Interceptor implementations
- API class structure and method signatures
- Response handling patterns
- Interface definitions and mixins

**error-handling.md** (if included):
- Error type definitions
- Error mapping strategies
- Recovery patterns

**dto-entity.md** (if included):
- Serialization patterns
- Parsing implementations
- Validation approaches

Use the Write tool to save each reference file to: `.claude/extraction/backends/{module-name}/references/{name}.md`
</generate_references>

<generate_manifest_entry>
Use the Read tool to get the project name from `pubspec.yaml`, then generate the manifest entry:

```json
{
  "backends/{module-name}": {
    "version": "0.1.0",
    "description": "{description}",
    "status": "extracted",
    "files": ["SKILL.md", "references/api-infrastructure.md", ...],
    "extracted_from": "{project_name from pubspec.yaml}",
    "extraction_date": "{YYYY-MM-DD}"
  }
}
```

Use the Write tool to save to: `.claude/extraction/backends/{module-name}/manifest-entry.json`
</generate_manifest_entry>

## Step 6: Verification and Report

<verification>
Verify the generated output using these tools:

1. Use the Read tool to check SKILL.md has valid YAML frontmatter
2. Use Glob to verify all referenced files exist in extraction directory
3. Use Grep to scan generated files for project-specific values: the project name from pubspec.yaml, domain-specific class names found during analysis, and URL patterns (`https?://[^/]+`)
4. Use the Read tool to verify manifest-entry.json is valid JSON

If project-specific values found, warn:
"WARNING: Found potential project-specific value in {file}:
  Line {n}: {content}
Consider generalizing before merging to CDN."
</verification>

<final_report>
Use Glob to list all files in `.claude/extraction/backends/{module-name}/` and present the actual generated file tree. Then present next steps:

```
Next steps:
1. Review the generated files in .claude/extraction/backends/
2. Check for any remaining project-specific values
3. When satisfied, copy SKILL.md and references/ to flutter-llm-toolkit/references/skills/{module-name}/
4. Use the toolkit README install prompt to add the new module to the selected projects
```
</final_report>

</process>

<reference_index>
Supporting files in `references/`:
- `agent-api-infrastructure.md` — Explore agent prompt for analyzing HTTP clients, API classes, and composition patterns. Read in Step 2 when API Infrastructure is selected.
- `agent-dto-entity.md` — Explore agent prompt for analyzing serialization, parsing, and validation patterns. Read in Step 2 when DTO/Entity is selected.
- `agent-error-handling.md` — Explore agent prompt for analyzing error types, mapping, and recovery patterns. Read in Step 2 when Error Handling is selected.
</reference_index>

<success_criteria>
- Final verification completed — no project-specific values left ungeneralized
- Additional research performed if user requested deeper investigation
- Explore agents analyzed the codebase in parallel (single message, not sequential)
- Findings presented and inconsistencies confirmed with user
- `create-skill` skill invoked before generating SKILL.md
</success_criteria>
