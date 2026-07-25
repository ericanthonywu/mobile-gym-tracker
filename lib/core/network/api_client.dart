import 'dart:async';
import 'package:dio/dio.dart';
import 'package:gym_tracker/core/config/app_config.dart';
import 'package:gym_tracker/core/storage/secure_storage.dart';

// ---------------------------------------------------------------------------
// Structured error types
// ---------------------------------------------------------------------------

enum ApiErrorType { connection, timeout, serverError, clientError, unauthorized, unknown }

class ApiError {
  final ApiErrorType type;
  final String message;
  const ApiError(this.type, this.message);
}

// ---------------------------------------------------------------------------
// Retry interceptor — retries GET failures with exponential backoff
// ---------------------------------------------------------------------------

class _RetryInterceptor extends Interceptor {
  static const int _maxRetries = 3;
  static const Set<String> _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  final Dio _dio;
  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    if (!_idempotentMethods.contains(method)) return handler.next(err);

    final isRetryable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.sendTimeout;

    if (!isRetryable) return handler.next(err);

    final attempt = (err.requestOptions.extra['_retryAttempt'] as int?) ?? 0;
    if (attempt >= _maxRetries) return handler.next(err);

    await Future.delayed(Duration(seconds: 1 << attempt));
    final options = err.requestOptions;
    options.extra['_retryAttempt'] = attempt + 1;

    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton Dio client with JWT interceptor + retry
// ---------------------------------------------------------------------------

class ApiClient {
  ApiClient._();

  static final Dio _dio = _buildDio();
  static Dio get instance => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    // JWT interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) => handler.next(error),
      ),
    );

    // Retry (added after JWT so retried requests include auth header)
    dio.interceptors.add(_RetryInterceptor(dio));

    return dio;
  }
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

ApiError parseApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final serverMessage =
        (data is Map && data.containsKey('error')) ? data['error'].toString() : null;

    if (error.type == DioExceptionType.connectionError) {
      return const ApiError(ApiErrorType.connection, 'Unable to connect. Check your network connection.');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiError(ApiErrorType.timeout, 'Connection timed out. Please try again.');
    }

    final statusCode = error.response?.statusCode ?? 0;
    if (statusCode == 401) {
      return const ApiError(ApiErrorType.unauthorized, 'Session expired. Please log in again.');
    }
    if (statusCode >= 500) {
      return ApiError(ApiErrorType.serverError, serverMessage ?? 'Server error. Please try again later.');
    }
    if (statusCode >= 400) {
      return ApiError(ApiErrorType.clientError, serverMessage ?? 'Something went wrong.');
    }
  }
  return const ApiError(ApiErrorType.unknown, 'Something went wrong. Please try again.');
}

String extractApiError(Object error) => parseApiError(error).message;
