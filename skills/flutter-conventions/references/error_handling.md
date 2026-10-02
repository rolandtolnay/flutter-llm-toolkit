# Error Handling

## Core Principle

Every exception type has **distinct localized title and message** — user screenshots identify the error type and code path without logs.

## Exception Hierarchy

```
Exception
├── LocalizedException (interface)      → UI-displayable errors with title + message
├── ExpectedException (marker)          → Skip crash reporting
│
├── AppDioException (abstract)          → Network/API errors
│   ├── ApiException                    → Server errors (4xx/5xx)
│   ├── NoInternetException             → No connectivity
│   └── NetworkException                → Timeouts, bad gateway
│
├── ParsingException                    → Contract mismatch (JSON parsing failed)
├── ResultError                         → Frontend bugs (assertions that failed)
│
└── DomainException (abstract)          → Expected business logic errors
    ├── NoActiveBookingException
    └── [Feature]Exception
```

| Exception | When | Crash report |
|-----------|------|-------------|
| `ApiException` | Server error response (4xx/5xx) | Report |
| `NoInternetException` | No connectivity (SocketException) | Skip |
| `NetworkException` | Timeouts, bad gateway | Skip |
| `ParsingException` | Null response, wrong JSON structure | Report |
| `ResultError` | Invalid frontend state | Report |
| `DomainException` | Expected business state | Skip |

## Base Interfaces

```dart
abstract class LocalizedException implements Exception {
  String? get localizedTitle;
  String get localizedMessage;
}

class ExpectedException implements Exception {}
```

## Network Exceptions

Wrap Dio errors, created by `ApiErrorInterceptor`:

```dart
abstract class AppDioException extends DioException {
  AppDioException(DioException? exception)
      : super(
          requestOptions: exception?.requestOptions ?? RequestOptions(),
          error: exception?.error,
          response: exception?.response,
          message: exception?.message,
          type: exception?.type ?? DioExceptionType.unknown,
        );
}

class ApiException extends AppDioException implements LocalizedException {
  ApiException({this.serverMessage, DioException? exception}) : super(exception);

  /// Error message from the server response, if available.
  final String? serverMessage;
  int? get statusCode => response?.statusCode;

  @override
  String get localizedTitle => tr(LocaleKeys.common_errors_server_title);
  @override
  String get localizedMessage => serverMessage ?? tr(LocaleKeys.common_errors_server_subtitle);
}

class NoInternetException extends AppDioException
    implements LocalizedException, ExpectedException {
  NoInternetException({DioException? exception}) : super(exception);

  @override
  String get localizedTitle => tr(LocaleKeys.common_errors_no_internet_title);
  @override
  String get localizedMessage => tr(LocaleKeys.common_errors_no_internet_description);
}

class NetworkException extends AppDioException
    implements LocalizedException, ExpectedException {
  NetworkException({DioException? exception}) : super(exception);

  @override
  String get localizedTitle => tr(LocaleKeys.common_errors_network_title);
  @override
  String get localizedMessage => tr(LocaleKeys.common_errors_network_subtitle);
}
```

## ParsingException

Thrown for JSON contract failures wrapped by the response parsing helpers. Captures context for remote debugging.

```dart
class ParsingException implements LocalizedException {
  const ParsingException({
    required this.message,
    this.endpoint,
    this.expectedType,
    this.rawJson,
    this.innerError,
  });

  final String message;
  final String? endpoint;
  final String? expectedType;
  final dynamic rawJson;
  final Object? innerError;

  @override
  String get localizedTitle => tr(LocaleKeys.common_errors_parsing_title);
  @override
  String get localizedMessage => tr(LocaleKeys.common_errors_parsing_subtitle);

  @override
  String toString() => 'ParsingException: $message'
      '${endpoint != null ? ' [endpoint: $endpoint]' : ''}'
      '${expectedType != null ? ' [expected: $expectedType]' : ''}'
      '${innerError != null ? ' [error: $innerError]' : ''}';
}
```

Use for a null response body or invalid JSON structure. Field conversion errors are wrapped only by helpers that catch `fromJson` failures; `parseDataSingle` currently lets those errors propagate unchanged.

## ResultError

Frontend bugs — invalid state that shouldn't occur. Always reported to the crash reporter.

```dart
class ResultError implements LocalizedException {
  const ResultError(this.message);

  final String message;

  @override
  String get localizedTitle => tr(LocaleKeys.common_errors_unexpected_title);
  @override
  String get localizedMessage => tr(LocaleKeys.common_errors_unexpected_subtitle);

  @override
  String toString() => 'ResultError: $message';
}
```

- Throw for: operations that should always succeed, required properties unexpectedly null, invalid frontend state
- Don't use for: API response issues → `ParsingException`, expected business states → `DomainException`

## Response Parsing Extensions

`extension ResponseParsingEx<T> on Response<T>` keeps API implementations lean: `parseSingle`, `parseWrapped`, `parseList`, `parseDataSingle` and `parseDataList` validate the body shape and call `fromJson`. Wrapped failures become a `ParsingException` carrying `endpoint`, `expectedType`, `rawJson` and `innerError`; `parseDataSingle` does not wrap its `fromJson` call, so field/type mismatches can escape as raw errors such as `TypeError`. List helpers log and skip malformed items instead of failing the whole response. Signatures and body shapes are in `rest_api.md`.

```dart
Future<CustomerEntity> getCustomer() async {
  final response = await _dio.get<Map<String, dynamic>>(_api.customer);
  return response.parseDataSingle(fromJson: CustomerEntity.fromJson, endpoint: 'getCustomer');
}
```

Always pass `endpoint:`; it is the only request context a parsing failure carries.

## DomainException

Expected business logic errors. Implements both `LocalizedException` and `ExpectedException` (skips crash reporting).

Create when: specific UI flow needed, feature-specific error copy, business rule violation tracking from screenshots. Don't create for errors that should use generic `ApiException` handling.

```dart
abstract class DomainException implements LocalizedException, ExpectedException {
  const DomainException();

  @override
  String? get localizedTitle => tr(LocaleKeys.common_errors_unexpected_title);
  @override
  String get localizedMessage => tr(LocaleKeys.common_errors_unexpected_subtitle);
}

class NoActiveBookingException extends DomainException {
  final String? details;
  const NoActiveBookingException([this.details]);

  @override
  String? get localizedTitle => tr(LocaleKeys.booking_no_active_title);
  @override
  String get localizedMessage => tr(LocaleKeys.booking_no_active_message);

  @override
  String toString() => 'No active booking${details != null ? ': $details' : ''}';
}
```

## API Error Interceptor

Place as **last interceptor** in Dio chain:

```dart
class ApiErrorInterceptor extends Interceptor {
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.error is SocketException) {
      handler.reject(NoInternetException(exception: err));
      return;
    }

    switch (err.response?.statusCode) {
      case HttpStatus.requestTimeout:
      case HttpStatus.badGateway:
      case HttpStatus.gatewayTimeout:
        handler.reject(NetworkException(exception: err));
        return;
    }

    handler.reject(ApiException(serverMessage: _serverMessage(err.response), exception: err));
  }
}
```

## UI Error Display

```dart
final localized = error is LocalizedException ? error : null;
final title = localized?.localizedTitle ?? tr(LocaleKeys.common_errors_uncaught_title);
final message = localized?.localizedMessage ?? tr(LocaleKeys.common_errors_uncaught_subtitle);
```

- **Error widgets** (`ErrorCard`): page initialization failures, include retry button
- **Toasts**: user-initiated action failures, retryable via same UI element
- **Dialogs**: errors requiring acknowledgment or additional context

## Crash Reporting

```dart
extension ExceptionConvenience on Object {
  bool get shouldReportToCrashlytics =>
      !isRequestCancelled && this is! ExpectedException;
}

if (error.shouldReportToCrashlytics) {
  crashlytics.recordError(error, stackTrace);
}
```

The same gate applies with Sentry, in `beforeSend` or in the provider failure observer (see `app_bootstrap.md`). Reporting happens in one place: the observer and the log listener (see `logging.md`), never in providers or widgets.

## Localization Keys

```json
{
  "common": {
    "errors": {
      "server_title": "Server Error",
      "server_subtitle": "Something went wrong. Please try again.",
      "no_internet_title": "No Internet",
      "no_internet_description": "Check your connection and try again.",
      "network_title": "Connection Problem",
      "network_subtitle": "Unable to reach the server.",
      "parsing_title": "Data Error",
      "parsing_subtitle": "We couldn't load the data. Please try again.",
      "unexpected_title": "Unexpected Error",
      "unexpected_subtitle": "Something went wrong. Please try again.",
      "uncaught_title": "Oops!",
      "uncaught_subtitle": "Something unexpected happened."
    }
  }
}
```
