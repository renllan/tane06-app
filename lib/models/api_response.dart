/// Generic API response wrapper and error model for the TanE06 API.
///
/// Every API response follows the shape:
/// ```json
/// { "success": true, "data": { ... } }
/// { "success": false, "error": { "code": "...", "message": "..." } }
/// ```
class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool,
      data: json['data'] != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Structured error returned by the TanE06 API.
class ApiError {
  final String code;
  final String message;

  const ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'Unknown',
      message: json['message'] as String? ?? 'Unknown error',
    );
  }

  @override
  String toString() => 'ApiError($code: $message)';
}

/// Exception thrown when an API call fails.
class ApiException implements Exception {
  final int statusCode;
  final ApiError error;

  const ApiException({required this.statusCode, required this.error});

  @override
  String toString() => 'ApiException($statusCode): ${error.message}';
}
