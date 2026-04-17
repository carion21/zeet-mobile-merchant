import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Logger HTTP uniquement actif en mode debug (stripped en release).
class ApiLogger {
  static void _log(String message) {
    if (!kDebugMode) return;
    for (final line in message.split('\n')) {
      debugPrint('[API] $line');
    }
  }

  static String _prettyJson(dynamic data) {
    try {
      final encoded = data is String ? data : jsonEncode(data);
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(encoded));
    } catch (_) {
      return '$data';
    }
  }

  static void logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer();
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- REQUEST');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- Method  : $method');
    buffer.writeln('-- URL     : $url');

    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('-- Headers :');
      for (final entry in headers.entries) {
        buffer.writeln('--   ${entry.key}: ${entry.value}');
      }
    }

    if (body != null) {
      buffer.writeln('-- Body    :');
      for (final line in _prettyJson(body).split('\n')) {
        buffer.writeln('--   $line');
      }
    }

    buffer.write('--------------------------------------------------');
    _log(buffer.toString());
  }

  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    dynamic body,
    Duration? duration,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer();
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- RESPONSE');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- Method  : $method');
    buffer.writeln('-- URL     : $url');
    buffer.writeln('-- Status  : $statusCode');

    if (duration != null) {
      buffer.writeln('-- Duration: ${duration.inMilliseconds}ms');
    }

    if (body != null) {
      buffer.writeln('-- Body    :');
      for (final line in _prettyJson(body).split('\n')) {
        buffer.writeln('--   $line');
      }
    }

    buffer.write('--------------------------------------------------');
    _log(buffer.toString());
  }

  static void logError({
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    dynamic requestBody,
    dynamic responseBody,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer();
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- ERROR');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('-- Method  : $method');
    buffer.writeln('-- URL     : $url');
    if (statusCode != null) {
      buffer.writeln('-- Status  : $statusCode');
    }
    buffer.writeln('-- Error   : $error');

    if (requestBody != null) {
      buffer.writeln('-- Input   :');
      for (final line in _prettyJson(requestBody).split('\n')) {
        buffer.writeln('--   $line');
      }
    }

    if (responseBody != null) {
      buffer.writeln('-- Response:');
      for (final line in _prettyJson(responseBody).split('\n')) {
        buffer.writeln('--   $line');
      }
    }

    if (stackTrace != null) {
      buffer.writeln('-- Stack   :');
      for (final line in stackTrace.toString().split('\n').take(5)) {
        buffer.writeln('--   $line');
      }
    }

    buffer.write('--------------------------------------------------');
    _log(buffer.toString());
  }
}
