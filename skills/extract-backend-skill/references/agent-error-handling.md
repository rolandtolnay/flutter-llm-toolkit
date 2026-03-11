Analyze this Flutter codebase for error handling patterns. Be very thorough.

SEARCH LOCATIONS:
- Files: **/*exception*.dart, **/*error*.dart, **/*failure*.dart
- Directories: **/core/error/**, **/utils/error/**
- Search for: try/catch patterns, throw statements, sealed class Exception
- Look in interceptors for error handling logic

FOCUS AREAS:
1. Error Types: Custom exception classes, sealed classes, error enums
2. Error Mapping: HTTP status code to domain error, server response parsing
3. Try/Catch: Catch specificity, propagation vs handling, rethrow patterns
4. Recovery: Automatic retry, fallback values, offline fallback
5. Logging: Debug vs production logging, crash reporting
6. User-Facing: Error message formatting, localized messages

OUTPUT FORMAT (JSON):
{
  "error_types": ["NetworkException", "ServerException", ...],
  "patterns": [
    {
      "name": "pattern name",
      "description": "what it does",
      "location": "file path",
      "code_snippet": "GENERALIZED with {App}, {Service}, {errorMessage} placeholders",
      "rationale": "why this pattern"
    }
  ],
  "dependencies": ["package:dio/dio.dart", ...],
  "recommendations": "what to include in module"
}

GENERALIZATION RULES:
- Replace app-specific exception names with {App}Exception
- Replace error messages with {errorMessage}
- Replace service names with {Service}
- Keep exception hierarchy structure
