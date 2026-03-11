Analyze this Flutter codebase for DTO and entity patterns. Be very thorough.

SEARCH LOCATIONS:
- Files: **/*_model.dart, **/*_dto.dart, **/*_entity.dart
- Directories: **/models/**, **/entities/**, **/data/models/**
- Look for classes with fromJson/toJson methods
- Check for freezed/json_serializable annotations

FOCUS AREAS:
1. Serialization Approach: json_serializable, freezed, manual, or mixed
2. fromJson/toJson: Factory constructors vs static methods, null safety
3. Nullable Handling: Required vs optional, default values
4. Nested Objects: List/Map parsing, recursive deserialization
5. Date/Time: ISO 8601, Unix timestamps, timezone handling
6. Enums: String-to-enum, unknown value handling, defaults
7. Validation: Constructor assertions, validation methods

OUTPUT FORMAT (JSON):
{
  "serialization_approach": "json_serializable|freezed|manual|mixed",
  "patterns": [
    {
      "name": "pattern name",
      "description": "what it does",
      "location": "file path",
      "code_snippet": "GENERALIZED with {Entity}, {field} placeholders",
      "rationale": "why this pattern"
    }
  ],
  "dependencies": ["package:freezed_annotation/freezed_annotation.dart", ...],
  "recommendations": "what to include in module"
}

GENERALIZATION RULES:
- Replace class names with {Entity}
- Replace field names with {field} where pattern matters
- Keep serialization annotations as-is
- Show nullable handling, date parsing, enum patterns
