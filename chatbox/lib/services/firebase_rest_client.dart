import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

/// Lightweight REST client for Firebase Realtime Database.
/// Provides direct HTTP access across all platforms (including Windows desktop, Linux, macOS, Android, iOS).
class FirebaseRestDatabaseClient {
  static final FirebaseRestDatabaseClient _instance =
      FirebaseRestDatabaseClient._internal();
  factory FirebaseRestDatabaseClient() => _instance;
  FirebaseRestDatabaseClient._internal();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  String get _baseUrl =>
      AppConstants.firebaseDatabaseUrl.replaceAll(RegExp(r'/+$'), '');

  Uri _buildUri(String path) {
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$_baseUrl/$cleanPath.json');
  }

  Future<dynamic> get(String path) async {
    try {
      final request = await _httpClient.getUrl(_buildUri(path));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body.isEmpty || body.trim() == 'null') return null;
        return jsonDecode(body);
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseRestDatabaseClient.get($path) error: $e');
      return null;
    }
  }

  Future<bool> put(String path, dynamic data) async {
    try {
      final request = await _httpClient.putUrl(_buildUri(path));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('FirebaseRestDatabaseClient.put($path) error: $e');
      return false;
    }
  }

  Future<bool> patch(String path, Map<String, dynamic> data) async {
    try {
      final request = await _httpClient.patchUrl(_buildUri(path));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('FirebaseRestDatabaseClient.patch($path) error: $e');
      return false;
    }
  }

  Future<bool> delete(String path) async {
    try {
      final request = await _httpClient.deleteUrl(_buildUri(path));
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('FirebaseRestDatabaseClient.delete($path) error: $e');
      return false;
    }
  }
}
