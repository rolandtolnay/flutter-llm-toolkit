Analyze this Flutter codebase for API infrastructure patterns. Be very thorough.

SEARCH LOCATIONS:
- Look for Dio setup, http package configuration in: **/http*.dart, **/api_client*.dart, **/dio*.dart
- Check **/core/network/**, **/data/remote/**, **/config/** for base URL definitions
- Find API classes with Repository, Service, Api suffixes in: **/data/repositories/**, **/api/**, **/services/**
- Find composition patterns in: **/core/contracts/**, **/domain/repositories/**

FOCUS AREAS:
1. HTTP Client: Library (Dio/http/retrofit), base config, interceptors, timeout, retry logic
2. API Classes: Organization pattern (repository/service/api), method signatures, pagination, caching
3. Composition: Abstract interfaces, mixins, DI patterns (Riverpod/GetIt/Provider)

OUTPUT FORMAT (JSON):
{
  "http_client": {
    "library": "dio|http|retrofit|custom",
    "patterns": [{"name": "...", "description": "...", "location": "...", "code_snippet": "GENERALIZED with {Entity}, {basePath} placeholders", "rationale": "..."}]
  },
  "api_classes": {
    "organization": "repository|service|api|mixed",
    "patterns": [{"name": "...", "description": "...", "location": "...", "code_snippet": "GENERALIZED", "rationale": "..."}]
  },
  "composition": {
    "patterns": [{"name": "...", "type": "abstract_class|mixin|interface", "description": "...", "location": "...", "code_snippet": "GENERALIZED", "rationale": "..."}]
  },
  "dependencies": ["package:dio/dio.dart", ...],
  "recommendations": "summary of what to include"
}

GENERALIZATION RULES:
- Replace entity names with {Entity} (PascalCase) or {entity} (camelCase)
- Replace API endpoints with {basePath}/{entities}
- Replace app-specific prefixes with {App}
- Keep library names (dio, riverpod) as-is
- Keep standard method names (fromJson, toJson) as-is
