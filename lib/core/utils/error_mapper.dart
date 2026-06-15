import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps raw Supabase/Postgrest/Auth/Function exceptions into short,
/// user-facing strings. Centralizing this means every repository and
/// screen shows consistent, friendly error copy instead of leaking raw
/// Postgres error text.
class ErrorMapper {
  ErrorMapper._();

  static String map(Object error) {
    if (error is AuthException) {
      return _mapAuthError(error);
    }
    if (error is PostgrestException) {
      return _mapPostgrestError(error);
    }
    if (error is FunctionException) {
      return _mapFunctionError(error);
    }
    if (error is StorageException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Something went wrong uploading that file. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String _mapAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('token') && message.contains('expired')) {
      return 'That code has expired. Please request a new one.';
    }
    if (message.contains('invalid') && message.contains('otp')) {
      return 'That code doesn\'t look right. Please check and try again.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    return error.message;
  }

  static String _mapPostgrestError(PostgrestException error) {
    // The "one active connection" rule and the 5-message cap are enforced
    // by Postgres triggers/constraints — surface them with friendly copy.
    final message = error.message.toLowerCase();
    if (message.contains('message') && (message.contains('limit') || message.contains('cap'))) {
      return 'You\'ve reached the message limit for this stage.';
    }
    if (message.contains('active connection') || message.contains('one connection')) {
      return 'You\'re already in an active connection. End it before starting a new one.';
    }
    if (error.code == '23505') {
      return 'That already exists.';
    }
    if (error.code == '42501' || message.contains('permission') || message.contains('policy')) {
      return 'You don\'t have permission to do that.';
    }
    return error.message.isNotEmpty ? error.message : 'Something went wrong. Please try again.';
  }

  static String _mapFunctionError(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is Map && details['message'] is String) {
      return details['message'] as String;
    }
    switch (error.status) {
      case 401:
        return 'Please log in again to continue.';
      case 403:
        return 'You\'re already in an active connection, or this action isn\'t allowed right now.';
      case 409:
        return 'That request has already been handled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
