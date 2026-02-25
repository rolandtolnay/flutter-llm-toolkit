---
description: Generates a comprehensive CLAUDE.md file for Flutter projects through systematic discovery and user consultation
allowed-tools: [Read, Glob, Grep, Bash, Task, Write, Edit, AskUserQuestion]
---

<objective>
Generate a high-quality CLAUDE.md file that enables AI assistants to effectively understand and work with a Flutter codebase. This involves systematic discovery of project structure, patterns, conventions, and business domain to create documentation that is accurate, complete, and immediately actionable.

**Core Principles:**
1. **Discovery Before Writing** - Never assume project details. Every section requires actual codebase investigation.
2. **Accuracy Over Completeness** - Better to document fewer features accurately than include incorrect information.
3. **Thoroughness Over Speed** - Use AskUserQuestion as many times as needed for complete clarity before composing.
4. **Pattern Recognition** - Capture how things are done in this specific project, not just what exists.
5. **Resolve Contradictions with User** - When finding conflicting patterns, always ask before documenting.
6. **Evidence-Based Claims** - For every non-trivial statement (architecture, state management patterns, naming conventions), include at least one concrete file example path (keep it lightweight: 1-3 paths per section).
</objective>

<workflow>

## Phase 1: Check for Existing CLAUDE.md

**First, check if CLAUDE.md already exists at project root.**

If CLAUDE.md exists:
1. Read the existing file completely
2. Analyze its structure, sections, and intentions
3. Use AskUserQuestion with these options:
   - **Overwrite completely**: Replace with freshly generated content
   - **Extend existing structure**: Keep the existing organization but enrich with template patterns
   - **Selective merge**: Ask about specific sections that differ

For merge/extend scenarios, be intelligent about:
- Understanding the intent behind each existing section
- How existing sections map to template sections
- Extending existing content with more detail rather than replacing
- Preserving custom project-specific sections not in template
- Ask user for clarity when the right approach is ambiguous

## Phase 2: Parallel Discovery with Explore Agents

Launch multiple Explore agents in parallel using the Task tool to gather project information efficiently:

**Agent 1: Technical Specifications**
```
Discover technical specifications for the Flutter project:
1. Read .fvm/fvm_config.json for Flutter version (if missing, check for .tool-versions/asdf or ask user)
2. Parse pubspec.yaml for:
   - Dart SDK constraint (environment section)
   - Primary packages used (state management, navigation, auth, analytics, crash reporting)
3. Parse pubspec.lock for resolved dependency versions (exact versions):
   - Prefer the primary package that represents a capability (e.g. auto_route, hooks_riverpod/flutter_riverpod, grpc)
   - If multiple packages are used for one capability (e.g. riverpod_annotation + riverpod_generator + flutter_riverpod), include the relevant set
4. Determine backend type using multiple signals (dependencies + generated code + imports):
   - grpc/protobuf deps + lib/generated/*.pb.dart → gRPC/Protobuf
   - firebase_* deps + firebase config files → Firebase
   - dio/http + JSON models → REST/HTTP
5. Discover localization setup:
   - Check pubspec.yaml dependencies for localization packages:
     - easy_localization → note asset paths from pubspec.yaml flutter.assets section
     - flutter_localizations + intl → uses ARB files with flutter gen-l10n
   - If easy_localization found, look for asset paths (default: assets/translations)
   - Search for localization documentation: rg --files -g '*localization*' -g '*l10n*' -g '*translation*' docs/ lib/
   - Return: l10n package name, configured paths (if discoverable), any guide files found
6. Return structured data with exact versions and the files used as evidence
```

**Agent 2: Feature Directory Analysis**
```
Analyze all feature directories in lib/:
1. Determine the actual top-level structure of lib/ (use eza if available; otherwise ls/find):
   - eza --tree --git-ignore lib/ -L 2
   - or: find lib -maxdepth 2 -type d
2. Identify feature directories (exclude: common, generated, l10n/translations, core, shared, packages)
3. For each feature directory:
   - Read the main screen file to understand purpose
   - Check provider files for functionality
   - Check entity files for domain models
4. Return list with 1-2 sentence descriptions following pattern:
   "lib/feature_name/ – [What it handles/enables/manages]. [Additional detail if complex]."
5. Order by importance: auth first, then core features, then supporting features
6. Include 1 representative file path per feature as evidence
```

**Agent 3: Custom Patterns Discovery**
```
Discover custom hooks and WidgetRef extensions:
1. Search lib/common/util/ for use_*.dart and *_hook.dart files
2. For each hook, extract:
   - Function signature
   - Purpose (one line)
   - Example usage
3. Search lib/common/extensions/ for widget_ref*.dart
4. Document error handling extensions (listenOnError, etc.)
5. Document condition-based listeners (listenForCondition, etc.)
6. Return structured documentation with code examples
```

**Agent 4: Business Entities Catalog**
```
Catalog all business entities in the project:
1. Find entity files (exclude generated):
   - Prefer: rg --files -g '*_entity.dart' lib
   - If the project uses different naming, also search for /entity/ and /entities/ directories
2. For each entity:
   - Read class definition and properties
   - Identify API type mapping (proto message, Firebase doc, JSON)
   - Note relationships between entities
3. Group by category if logical grouping exists
4. Return formatted list: "**Entity Name** (API Type) - Description"
```

**Agent 5: Widget Catalog**
```
Catalog widgets in lib/common/widgets/:
1. Scan subdirectory structure (atoms/, molecules/, button/, input/, sheet/, container/, list/)
2. Identify the 8-12 most frequently imported widgets across the codebase
3. For each essential widget: name and primary use case
4. Document subdirectory organization pattern
5. Check if docs/guides/UI_GUIDE.md exists
6. Return organized widget catalog
```

**Agent 6: Screen Pattern Analysis**
```
Analyze screen implementation patterns:
1. Read 3-4 different screen files from various features
2. Identify common patterns:
   - Scaffolding approach (AppScaffold, Scaffold)
   - Error handling (ref.listenOnError, manual try-catch)
   - Loading states (.when(), .isLoading)
   - Pull-to-refresh patterns
3. Note any pattern inconsistencies between screens
4. Return the canonical screen pattern with code example
```

## Phase 3: Check Documentation Files

After exploration completes:

1. **Check for Riverpod guide**
   - Check `.claude/references/riverpod.md` or `docs/guides/RIVERPOD.md`
   - If neither exists, use AskUserQuestion: "Riverpod guide not found at `.claude/references/riverpod.md` or under docs/. Should the CLAUDE.md omit the Riverpod patterns reference, or do you want to provide its location?"

2. **Check for .claude/references/code_quality.md**
   - If missing, use AskUserQuestion: ".claude/references/code_quality.md not found. Should the CLAUDE.md omit the Code Quality reference, or do you want to provide its location?"

3. **Check for docs/guides/UI_GUIDE.md**
   - If present, include reference in widget documentation
   - If missing, omit reference without asking

4. **Check for localization setup** (from Agent 1 results)
   - If easy_localization detected but asset/output paths are unclear, use AskUserQuestion: "I found easy_localization in dependencies. What are your asset and output paths? (default: assets/translations → lib/generated/translations)"
   - If both easy_localization AND flutter_localizations/intl detected, use AskUserQuestion: "Both easy_localization and flutter_localizations are in dependencies. Which is the primary localization system used in this project?"
   - If localization guide file found, include reference in output
   - If no localization package detected, note to include "No localization setup detected" in output

## Phase 4: Contradiction Detection

Review discovery results for contradictions:

- **Pattern inconsistencies**: Same task done differently (e.g., some screens use centralized error handling, others don't)
- **Naming convention violations**: Files/classes not following dominant patterns
- **Architectural drift**: Business logic in UI vs properly in providers
- **Documentation vs reality**: CODE_QUALITY.md says X but code does Y

**For each contradiction, use AskUserQuestion:**
- Present both patterns with file examples
- Ask which represents the project's direction
- Ask if other pattern should be noted as "to migrate" or ignored

## Phase 5: Pre-Composition Clarity

Before composing CLAUDE.md, use AskUserQuestion to confirm:

1. **Introduction accuracy**: "Based on my analysis, this is a [domain] app for [users] that [value prop]. Is this accurate, or should I adjust?"

2. **Feature prioritization**: If uncertain about feature importance ordering

3. **Any missing context**: "Is there anything important about how the team works with this codebase that I should include?"

4. **Closing statement tone**: Confirm if production/internal/MVP tone is appropriate

Only proceed to composition after complete clarity is achieved.

## Phase 6: Compose CLAUDE.md

Generate the file using the template structure below, replacing all [DISCOVER] sections with actual findings.

</workflow>

<template_structure>

The following is the complete template. Sections marked [STATIC] must be preserved exactly. Sections marked [DISCOVER] must be replaced with discovered content.

````markdown
# CLAUDE.md

[DISCOVER: Introduction - 2-3 sentences]
Formula: "You are Claude, an AI assistant working with a human developer on a Flutter mobile app for [DOMAIN]. This [white-label/standalone/SaaS] solution empowers [TARGET_USERS] to [PRIMARY_VALUE_PROPOSITION]. As a [modern alternative to/solution for] [COMPARABLE_PLATFORMS], it provides [KEY_FEATURES]."

Example:
"You are Claude, an AI assistant working with a human developer on a Flutter mobile app for merchant payments. This white-label solution empowers small businesses to track and manage payments through an intuitive, mobile-first interface. As a modern alternative to platforms like SumUp and Dojo, it provides transaction visibility, digital onboarding, and comprehensive merchant services."

---

## Technical Specifications

[DISCOVER: From pubspec.yaml and .fvm/fvm_config.json - exact versions required]

Format:
- **Flutter**: X.X.X (via FVM)
- **Dart SDK**: ^X.X.X
- **State Management**: Riverpod X.X.X with code generation
- **Navigation**: [Package Name] X.X.X
- **Backend**: [gRPC with Protocol Buffers / Firebase / REST API]
- **Authentication**: [Service/SDK]
- **UI Framework**: [Name] X.X.X
- **Key Services**: [Service1], [Service2], [Service3]

---

## Project Structure

[STATIC - preserve this structure exactly]
```
lib/
├── feature/                    # Feature modules
│   ├── domain/                # Business entities, APIs, DTOs
│   │   ├── feature_api.dart  # API interface with gRPC
│   │   ├── feature_entity.dart # Domain models
│   │   └── create_feature_dto.dart # Data transfer objects
│   ├── provider/              # State management
│   │   ├── feature_list_provider.dart # List with pagination
│   │   └── create_feature_provider.dart # Mutations
│   ├── widgets/               # Feature-specific UI components
│   └── feature_screen.dart    # Screen implementations
├── common/                    # Shared utilities
│   ├── widgets/              # Reusable UI components (atoms/, molecules/, button/, etc.)
│   ├── theme/                # App colors and typography
│   ├── extensions/           # Dart extensions
│   └── util/                 # Hooks, validators, and utilities
├── packages/                  # Custom internal packages (if any)
└── generated/                # Auto-generated code
    ├── [proto/graphql/etc]/  # API-generated files
    └── translations/         # Localization keys
```

[DISCOVER: Prefer documenting the project's real lib/ tree. If the project does not match this structure, replace the whole code block with the actual structure (do not force-fit).]

### Core Features

[DISCOVER: All feature directories with 1-2 sentence descriptions]
Format:
- \`lib/auth/\` – Manages user authentication and session handling.
- \`lib/dashboard/\` – Displays main overview with key metrics and quick actions.
- \`lib/feature_name/\` – [Description of what this feature does].

Order by importance: auth first, then core business features, then supporting features.

---

## Architecture Philosophy

[STATIC - preserve exactly]
1. **Maintainability First** - Code should be easy to reason about and modify
2. **Pattern Consistency** - Always follow existing patterns before creating new ones
3. **Type Safety** - Leverage Dart's type system for compile-time safety
4. **80/20 Performance** - Capture low-hanging fruit without sacrificing readability
5. **Simplified CLEAN Architecture** - Clear separation between UI, Provider, and API layers

---

## Layer Responsibilities

### API Layer (\`domain/\`)

[STATIC - preserve these bullets]
- Wraps API communication with type-safe interfaces
- Converts between API messages and domain entities
- Handles account/user-scoped operations
- Example: \`PaymentIntentApi\` converts [DISCOVER: "proto \`PaymentIntent\`" / "Firestore document" / "JSON response"] to \`PaymentIntentEntity\`

**DO:**
- Define app-level entities for all API types
- Use extension methods for API-to-entity conversion
- Include comprehensive error handling
- Log successful operations

**DON'T:**
- Expose API types beyond the API layer
- Include business logic (keep in providers)
- Return null for errors (throw instead)

---

### Provider Layer (\`provider/\`)

[STATIC - preserve exactly]
- Manages application state using Riverpod
- Orchestrates business logic and API calls
- Handles loading states and errors with AsyncValue
- Invalidates dependent providers after mutations

**DO:**
- Use functional providers for data fetching
- Use class-based providers for mutations
- Always check for null account/user before API calls
- Use \`AsyncValue.guard()\` for error handling

**DON'T:**
- Make direct API calls from UI
- Forget to invalidate related providers
- Mix data fetching and mutation logic

---

### UI Layer (\`screens/\` and \`widgets/\`)

[STATIC - preserve exactly]
- Presents data and handles user interactions
- Communicates exclusively through providers
- Uses existing widget patterns for consistency
- Implements pull-to-refresh and infinite scroll

**DO:**
- Use \`HookConsumerWidget\` for screens
- Handle loading/error states with \`.when()\`
- Reuse existing widgets from \`common/widgets/\`
- Follow established spacing constants

**DON'T:**
- Create new widgets without checking for existing ones
- Make API calls directly
- Handle complex business logic

---

## Common Patterns

### Entity Pattern

[STATIC structure, DISCOVER: adapt API type in comment and extension]
```dart
@JsonSerializable(explicitToJson: true)
class PaymentEntity {
  final String id;
  final String name;
  final DateTime createdAt;

  PaymentEntity({required this.id, required this.name, required this.createdAt});
}

// [DISCOVER: Adapt comment - "Proto conversion" / "Firestore conversion" / "JSON conversion"]
extension on Payment {
  PaymentEntity toEntity() => PaymentEntity(
    id: name.split('/').last,
    name: displayName,
    createdAt: createTime.toDateTime(toLocal: true),
  );
}
```

### List Provider Pattern

[STATIC - preserve exactly]
```dart
@Riverpod(keepAlive: true)
class PaymentList extends _$PaymentList {
  PaymentApi get _api => ref.read(paymentApiProvider);

  @override
  FutureOr<PaymentListResult> build() async {
    final account = await ref.watch(selectedAccountProvider.future);
    if (account == null) return const PaymentListResult();

    return _api.getPaymentList(account: account);
  }

  Future<void> loadMore() async {
    // Pagination logic with copyWithPrevious
  }
}
```

### Screen Pattern

[DISCOVER: Base on actual screen patterns found - include centralized error handling if project uses it]
```dart
@RoutePage()
class PaymentDetailScreen extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentDetailProvider(id));

    // Centralized error handling - shows toast on provider errors
    ref.listenOnError(paymentDetailProvider(id));

    return AppScaffold(
      loading: state.isLoading,
      body: state.when(
        data: (data) => _buildContent(data),
        loading: () => const SizedBox.shrink(),
        error: (error, _) => ErrorRetryWidget(
          error: error,
          onRetry: () => ref.invalidate(paymentDetailProvider(id)),
        ),
      ),
    );
  }
}
```

### Custom Hooks

[DISCOVER: Only include if custom hooks exist in lib/common/util/. Document with signatures and examples.]

Example format:
```dart
// Execute callback once on mount (synchronously)
useInit(() => analytics.trackScreenView('PaymentDetail'));

// Execute callback once on mount (asynchronously, avoids frame issues)
useInitAsync(() => ref.read(provider.notifier).loadData());

// Async effect with optional keys for re-execution
useAsyncEffect(() => loadSomething(), [dependency]);
```

### WidgetRef Extensions

[DISCOVER: Only include if extensions exist in lib/common/extensions/. Document with examples.]

Example format:
```dart
// Centralized error handling - shows AppToast on provider errors
ref.listenOnError(someProvider);

// Condition-based listener - fires only on state transition
ref.listenForCondition(
  provider,
  (state) => state.isSuccess,
  (state) => context.router.maybePop(),
);
```

---

## Command Reference

### Development

[STATIC - preserve exactly]
```bash
# Run with specific Flutter version
fvm flutter run

# Code generation (required after modifying providers/routes/models)
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for continuous generation
fvm flutter pub run build_runner watch --delete-conflicting-outputs

# Format and fix code
fvm dart format . && fvm dart fix --apply

# List files in the project
eza --tree --git-ignore lib/ test/ -L 3
```

### Localization

[DISCOVER: Based on localization package detected in Agent 1]

**If easy_localization detected:**
```bash
# Generate translation keys after updating JSON files
fvm dart run easy_localization:generate -S [ASSET_PATH] -O [OUTPUT_PATH]
fvm dart run easy_localization:generate -S [ASSET_PATH] -O [OUTPUT_PATH] -f keys -o locale_keys.g.dart
```
Replace [ASSET_PATH] and [OUTPUT_PATH] with discovered or confirmed paths (defaults: assets/translations, lib/generated/translations).

**If flutter_localizations/intl (ARB) detected:**
```bash
# Generate localization files from ARB
fvm flutter gen-l10n
```

**If no localization detected:**
Output: "No localization setup detected in this project."

---

## Decision Framework

[STATIC - preserve exactly]

### Proceed Autonomously
- Choosing between existing UI components
- Following established CRUD patterns
- Creating providers/APIs when specified in task
- Using existing translation keys
- Implementing standard mobile patterns

### Ask for Clarification
- Business logic affecting user experience
- Information display priorities
- Domain-specific processing rules
- Breaking changes to existing features
- Security-sensitive operations

---

## Quick Reference

### Business Entities

[DISCOVER: All entities from lib/*/domain/*_entity.dart]
Format:
- **EntityName** (APIType) - Description of what it represents
- **Payments** (PaymentIntent) - Transaction records showing money movement
- **Devices** - Physical point-of-sale terminals for card processing

### Naming Conventions

[STATIC - preserve exactly]
- **Files**: \`feature_name.dart\` (snake_case)
- **Classes**: \`FeatureName\` (PascalCase)
- **Providers**: \`featureNameProvider\` (camelCase)
- **Widgets**: \`FeatureNameWidget\` or \`AppFeatureName\`
- **Screens**: \`FeatureScreen\` or \`FeatureDetailScreen\`

### Essential Widgets

[DISCOVER: 8-12 most-used widgets from lib/common/widgets/]
Core widgets for most screens:
- \`AppScaffold\` - Standard screen container with loading state
- \`AppPrimaryButton\` / \`AppSecondaryButton\` / \`AppGhostButton\` - Action buttons
- \`LabeledValue.row()\` - Key-value display pairs
- \`SectionBox\` - Card containers for grouped content
- \`ErrorRetryWidget\` - Error state with retry action
- \`AppToast.show()\` / \`AppToast.showError()\` - User feedback
- \`ScrollableCtaContent\` - Form layout with bottom CTA
- \`AppBottomSheet\` - Modal bottom sheets

**Discovering more widgets:** Browse \`lib/common/widgets/\` organized by type:
[DISCOVER: List actual subdirectories found]
- \`atoms/\` - Basic elements (chips, dividers, badges)
- \`molecules/\` - Composite widgets (pill switcher, searchable title)
- \`button/\` - All button variations
- \`input/\` - Form fields and inputs
- \`sheet/\` - Modals and pickers
- \`container/\` - Layout wrappers
- \`list/\` - List components and infinite scroll

[DISCOVER: If docs/guides/UI_GUIDE.md exists, include this line]
For detailed widget documentation with examples, see \`docs/guides/UI_GUIDE.md\`.

### Spacing Constants

[DISCOVER: From lib/common/theme/ or constants file]
```dart
const kBoxSpacing = 16.0;          // Between components
const kBoxSectionSpacing = 24.0;   // Between sections
const kLargeSectionSpacing = 32.0; // Major sections
```

---

## Documentation Standards

[STATIC - preserve exactly]
Write concise DartDoc comments for clarity:
- One-line summary explaining purpose
- 2-5 lines on usage/behavior
- Note edge cases or business rules
- Document only non-obvious parameters

```dart
/// Calculates refund amount including processing fees.
///
/// Returns 0 if amount exceeds original payment. Fee calculation
/// uses merchant's configured rate (default 2.9% + $0.30).
/// Partial refunds must be at least $1.00.
double calculateRefundAmount(
  double originalAmount,
  double refundAmount,
  double feeRate, // Must be between 0-1
) {
  // Implementation
}
```

---

## Anti-Patterns to Avoid

**Architecture:**
[STATIC - preserve exactly]
- Using API types directly in UI code
- Creating providers without checking for existing ones
- Bypassing the provider layer for API calls
- Implementing features without following existing patterns

**Code Quality (commonly missed):**
[DISCOVER: Extract 5-8 from .claude/references/code_quality.md if it exists, otherwise use these defaults]
- Using mutable collection methods: use \`.sorted()\` not \`.toList()..sort()\`
- Direct nullable callback invocation: use \`onDismiss?.call()\` not \`onDismiss!()\`
- Forgetting to trim text input: always \`controller.text.trim()\` on capture
- Scattering business logic in UI: encapsulate in entity computed properties
- Manual try-catch in screens: use \`ref.listenOnError()\` for centralized error handling
- Adding comments that duplicate obvious code
- Creating abstractions before they're needed

---

## Testing Philosophy

[STATIC - preserve exactly]
Unit test business logic on a need-to-test basis:
- Complex calculations or data transformations
- Business rule validations
- State management logic with side effects
- API response parsing with edge cases

Skip testing:
- Simple UI widgets
- Direct API wrappers
- Generated code

---

## Working Effectively

[STATIC - preserve exactly]
1. **Research First**: Always investigate existing patterns before implementing
2. **Plan Implementation**: Outline approach using existing components
3. **Follow Patterns**: Use established conventions consistently
4. **Validate Reuse**: Check if functionality already exists
5. **Run Generators**: Execute code generation after changes
6. **Format Code**: Run format/fix before considering done

---

[DISCOVER: Include these sections only if the corresponding files exist]

## Riverpod Patterns

[DISCOVER: Reference the Riverpod guide path, e.g. @.claude/references/riverpod.md]

## Code Quality Guidelines

[DISCOVER: Reference the code quality guide path, e.g. @.claude/references/code_quality.md]

---

[DISCOVER: Closing statement based on app type - confirm with user]

**For Production/Customer-facing apps:**
Remember: This is a production app serving real [users]. Prioritize reliability, maintainability, and consistent user experience over clever solutions. When in doubt, follow existing patterns in the codebase.

**For Internal tools:**
Remember: This tool supports internal operations. Prioritize maintainability and clear documentation over optimization. When in doubt, follow existing patterns.

**For MVP/Startup apps:**
Remember: This is an evolving product. Prioritize speed and iteration while maintaining code quality. When in doubt, follow existing patterns.
````

</template_structure>

<quality_checklist>
Before finalizing CLAUDE.md, verify all items:

**Technical Specifications**
- [ ] Flutter version matches `.fvm/fvm_config.json` exactly
- [ ] Dart SDK matches `pubspec.yaml` environment section
- [ ] Dependency versions are exact (prefer `pubspec.lock` for resolved versions)
- [ ] Backend type correctly identified and examples adapted
- [ ] Specs section cites evidence files (e.g. `.fvm/fvm_config.json`, `pubspec.lock`)

**Feature Documentation**
- [ ] Every `lib/*/` directory documented (excluding common, generated)
- [ ] Descriptions follow "handles/enables/manages" pattern
- [ ] Ordered by importance (auth first, then core, then supporting)
- [ ] No directories missed or incorrectly described

**Pattern Accuracy**
- [ ] Custom hooks documented with actual signatures from code
- [ ] WidgetRef extensions verified against actual implementation
- [ ] Screen pattern reflects actual error handling approach used
- [ ] Entity pattern uses correct API type (proto/Firebase/REST)
- [ ] Each documented pattern includes 1-3 example file paths

**Widget Documentation**
- [ ] 8-12 most-used widgets identified by import frequency
- [ ] Subdirectory organization matches actual structure
- [ ] UI_GUIDE.md referenced only if it exists

**Business Entities**
- [ ] All entity files discovered and documented
- [ ] API type mappings are accurate
- [ ] Descriptions explain business meaning, not just technical structure

**Documentation References**
- [ ] All @docs references point to files that exist
- [ ] User confirmed handling of missing docs files
- [ ] No broken file references

**Localization**
- [ ] Localization commands match the actual l10n package used (easy_localization vs flutter_localizations/intl)
- [ ] Asset/output paths verified from pubspec.yaml or confirmed with user
- [ ] If no l10n detected, section includes appropriate note

**Contradiction Resolution**
- [ ] All pattern inconsistencies identified
- [ ] User consulted for each contradiction using AskUserQuestion
- [ ] Documented patterns reflect project's desired direction
- [ ] Legacy patterns noted as "to migrate" where applicable

**Final Checks**
- [ ] No template placeholder text or [DISCOVER] markers remain
- [ ] Introduction accurately describes the domain
- [ ] Closing statement appropriate for app type
- [ ] File is properly formatted markdown
</quality_checklist>

<success_criteria>
Generation is complete when:
1. Existing CLAUDE.md handled per user preference (if applicable)
2. All 6 parallel Explore agents completed discovery
3. Missing docs files addressed with user via AskUserQuestion
4. All contradictions resolved with user consultation
5. Pre-composition clarity achieved through AskUserQuestion
6. CLAUDE.md written to project root
7. All quality checklist items verified
8. No placeholder or template instruction text remains
</success_criteria>
