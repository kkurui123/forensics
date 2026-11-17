import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// A readable API error for display in the interface.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  // Backend root URL. Do not append /api/v1.
  static const String baseUrl = 'https://securechat-dp0j.onrender.com';

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const String _tokenKey = 'access_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();

  // ---------------------------------------------------------
  // URL HELPERS
  // ---------------------------------------------------------

  Uri _rootUri() {
    final root = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

    final parsed = Uri.tryParse(root);

    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        (parsed.path.isNotEmpty && parsed.path != '/') ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const ApiException(
        'Use your HTTPS backend root URL without /api/v1 or /docs.',
      );
    }

    return parsed;
  }

  Uri _uri(String path) {
    final root = _rootUri();
    final endpoint = path.startsWith('/') ? path : '/$path';

    return root.resolve('/api/v1$endpoint');
  }

  Uri get socketUri {
    return _rootUri().replace(scheme: 'wss', path: '/api/v1/ws');
  }

  // ---------------------------------------------------------
  // TOKEN STORAGE
  // ---------------------------------------------------------

  Future<String?> getAccessToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> logout() {
    return _storage.delete(key: _tokenKey);
  }

  // ---------------------------------------------------------
  // COMMON REQUEST HANDLING
  // ---------------------------------------------------------

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Please log in to continue.',
          statusCode: 401,
        );
      }

      headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, _uri(path));

    request.headers.addAll(headers);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    late final http.Response response;

    try {
      response = await (() async {
        final streamedResponse = await _client.send(request);

        return http.Response.fromStream(streamedResponse);
      })()
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect to the server. Check your internet '
        'connection and try again.',
      );
    }

    if (authenticated && response.statusCode == 401) {
      await logout();
    }

    dynamic data;

    if (response.body.trim().isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode >= 400) {
          throw ApiException(
            _errorMessage(null, response.statusCode),
            statusCode: response.statusCode,
          );
        }

        throw ApiException(
          'The server returned an unexpected response '
          '(${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      _errorMessage(data, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(dynamic data, int statusCode) {
    final dynamic detail = data is Map ? data['detail'] : null;

    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    if (detail is List && detail.isNotEmpty) {
      return detail.map<String>((item) {
        if (item is! Map) {
          return 'Invalid input.';
        }

        final location = item['loc'];

        final field = location is List && location.isNotEmpty
            ? location.last.toString()
            : 'Input';

        final message = item['msg']?.toString() ?? 'Invalid value';

        return '$field: $message';
      }).join('\n');
    }

    switch (statusCode) {
      case 400:
        return 'Unable to process this request. Check your details.';
      case 401:
        return 'Your credentials are invalid or your session has '
            'expired. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'The request conflicts with an existing record.';
      case 413:
        return 'The message or file is too large.';
      case 422:
        return 'Please check the information you entered.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'The server encountered an error. Please check '
            'the backend logs.';
      case 501:
        return 'This feature has not been implemented on the server.';
      case 502:
      case 503:
      case 504:
        return 'The service is temporarily unavailable. '
            'Please try again.';
      default:
        return 'Request failed ($statusCode). Please try again.';
    }
  }

  Map<String, dynamic> _asObject(dynamic data) {
    if (data is! Map) {
      throw const ApiException(
        'The server returned an unexpected response format.',
      );
    }

    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> _asObjectList(dynamic data) {
    if (data is! List) {
      throw const ApiException(
        'The server returned an unexpected list format.',
      );
    }

    return data.map<Map<String, dynamic>>((item) {
      return _asObject(item);
    }).toList();
  }

  // ---------------------------------------------------------
  // GUARD REGISTRATION
  // ---------------------------------------------------------

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String zone,
    required String password,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/auth/register',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'zone': zone,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
  }

  // ---------------------------------------------------------
  // ADMIN / GUARD LOGIN
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String expectedRole,
  }) async {
    await logout();

    final data = _asObject(
      await _request(
        'POST',
        '/auth/login',
        body: {
          'identifier': identifier.trim(),
          'password': password,
        },
      ),
    );

    final rawUser = data['user'];
    final accessToken = data['access_token'];

    if (rawUser is! Map || accessToken is! String || accessToken.isEmpty) {
      throw const ApiException(
        'The server returned an invalid login response.',
      );
    }

    final user = Map<String, dynamic>.from(rawUser);
    final actualRole = user['role'];

    if (actualRole != 'GUARD' && actualRole != 'ADMIN') {
      throw const ApiException(
        'This account has an unsupported role.',
      );
    }

    if (actualRole != expectedRole.toUpperCase()) {
      throw ApiException(
        'This is a ${actualRole.toString().toLowerCase()} account. '
        'Return to role selection and choose the correct role.',
      );
    }

    await _storage.write(
      key: _tokenKey,
      value: accessToken,
    );

    return user;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return _asObject(
      await _request(
        'GET',
        '/auth/me',
        authenticated: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // GUARD DIRECTORY
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getGuards({
    String search = '',
  }) async {
    final query = Uri.encodeQueryComponent(search.trim());

    return _asObjectList(
      await _request(
        'GET',
        '/guards?q=$query',
        authenticated: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // CONVERSATIONS
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> openConversation(String guardId) async {
    return _asObject(
      await _request(
        'POST',
        '/conversations',
        authenticated: true,
        body: {
          'guard_id': guardId,
        },
      ),
    );
  }

  Future<void> registerEncryptionPublicKey(
    String publicKey,
  ) async {
    await _request(
      'POST',
      '/encryption-key',
      authenticated: true,
      body: {
        'public_key': publicKey,
      },
    );
  }

  Future<String?> getGuardEncryptionPublicKey(
    String guardId,
  ) async {
    final id = Uri.encodeComponent(guardId);

    final data = _asObject(
      await _request(
        'GET',
        '/guards/$id/encryption-key',
        authenticated: true,
      ),
    );

    final value = data['public_key'];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw const ApiException(
        'The server returned an invalid encryption key.',
      );
    }

    return value;
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    return _asObjectList(
      await _request(
        'GET',
        '/conversations',
        authenticated: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // UNREAD MESSAGES
  // ---------------------------------------------------------

  Future<Map<String, int>> getUnreadCounts() async {
    final rows = _asObjectList(
      await _request(
        'GET',
        '/conversations/unread-counts',
        authenticated: true,
      ),
    );

    final counts = <String, int>{};

    for (final row in rows) {
      final conversationId = row['conversation_id']?.toString() ?? '';
      final unreadCount = row['unread_count'];

      if (conversationId.isEmpty) {
        continue;
      }

      counts[conversationId] = unreadCount is int ? unreadCount : 0;
    }

    return counts;
  }

  Future<Map<String, dynamic>> markConversationRead(
    String conversationId,
  ) async {
    final id = Uri.encodeComponent(conversationId);

    return _asObject(
      await _request(
        'POST',
        '/conversations/$id/mark-read',
        authenticated: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // MESSAGE HISTORY
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw const ApiException(
        'Message limit must be 1–100 and offset cannot be negative.',
      );
    }

    final id = Uri.encodeComponent(conversationId);

    return _asObjectList(
      await _request(
        'GET',
        '/conversations/$id/messages?limit=$limit&offset=$offset',
        authenticated: true,
      ),
    );
  }

  // ---------------------------------------------------------
  // ENCRYPTED TEXT
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> sendEncryptedText(
    String conversationId,
    String clientMessageId,
    String ciphertext,
  ) async {
    if (ciphertext.isEmpty) {
      throw const ApiException(
        'The encrypted message cannot be empty.',
      );
    }

    final id = Uri.encodeComponent(conversationId);

    return _asObject(
      await _request(
        'POST',
        '/conversations/$id/messages',
        authenticated: true,
        body: {
          'client_message_id': clientMessageId,
          'kind': 'TEXT',
          'ciphertext': ciphertext,
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // WEBSOCKET AUTHENTICATION
  // ---------------------------------------------------------

  Future<String> getSocketToken() async {
    final data = _asObject(
      await _request(
        'POST',
        '/ws-token',
        authenticated: true,
      ),
    );

    final socketToken = data['token'];

    if (socketToken is! String || socketToken.isEmpty) {
      throw const ApiException(
        'The server returned an invalid connection token.',
      );
    }

    return socketToken;
  }

  // ---------------------------------------------------------
  // HEALTH CHECK
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> checkHealth() async {
    return _asObject(
      await _request(
        'GET',
        '/health/ready',
      ),
    );
  }

  Future<String> uploadProfilePhoto(String filePath) async {
    final token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Please log in to continue.',
        statusCode: 401,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      _uri('/me/profile-photo'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    final photoFile = await http.MultipartFile.fromPath(
      'photo',
      filePath,
      filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: MediaType('image', 'jpeg'),
    );

    request.files.add(photoFile);

    late final http.StreamedResponse response;

    try {
      response = await request.send().timeout(
            _requestTimeout,
          );
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect to the server. Check your internet '
        'connection and try again.',
      );
    }

    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic data;

      if (body.trim().isNotEmpty) {
        try {
          data = jsonDecode(body);
        } on FormatException {
          data = null;
        }
      }

      throw ApiException(
        _errorMessage(
          data,
          response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    dynamic data;

    try {
      data = jsonDecode(body);
    } on FormatException {
      throw const ApiException(
        'The server returned an unexpected response format.',
      );
    }

    final result = _asObject(data);

    final photoUrl = result['profile_photo_url'];

    if (photoUrl is! String || photoUrl.isEmpty) {
      throw const ApiException(
        'The server did not return the updated profile photo.',
      );
    }

    return photoUrl;
  }

  // ---------------------------------------------------------
  // INCIDENTS
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> createIncident({
    required String reportType,
    String? conversationId,
    String? reportedGuardId,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'report_type': reportType,
      'reason': reason.trim(),
    };

    if (conversationId != null && conversationId.isNotEmpty) {
      body['conversation_id'] = conversationId;
    }

    if (reportedGuardId != null && reportedGuardId.isNotEmpty) {
      body['reported_guard_id'] = reportedGuardId;
    }

    return _asObject(
      await _request(
        'POST',
        '/incidents',
        authenticated: true,
        body: body,
      ),
    );
  }

  // ---------------------------------------------------------
  // ADMIN USERS
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    return _asObjectList(
      await _request(
        'GET',
        '/admin/users',
        authenticated: true,
      ),
    );
  }

  Future<Map<String, dynamic>> suspendUser(String userId) async {
    final id = Uri.encodeComponent(userId);

    return _asObject(
      await _request(
        'PATCH',
        '/admin/users/$id/suspend',
        authenticated: true,
      ),
    );
  }

  Future<Map<String, dynamic>> activateUser(String userId) async {
    final id = Uri.encodeComponent(userId);

    return _asObject(
      await _request(
        'PATCH',
        '/admin/users/$id/activate',
        authenticated: true,
      ),
    );
  }

  Future<Map<String, dynamic>> changeUserRole(
    String userId,
    String role,
  ) async {
    final id = Uri.encodeComponent(userId);

    return _asObject(
      await _request(
        'PATCH',
        '/admin/users/$id/role',
        authenticated: true,
        body: {
          'role': role,
        },
      ),
    );
  }

  Future<void> deleteUser(String userId) async {
    final id = Uri.encodeComponent(userId);

    await _request(
      'DELETE',
      '/admin/users/$id',
      authenticated: true,
    );
  }

  // ---------------------------------------------------------
  // ADMIN INCIDENTS
  // ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAdminIncidents() async {
    return _asObjectList(
      await _request(
        'GET',
        '/admin/incidents',
        authenticated: true,
      ),
    );
  }

  Future<Map<String, dynamic>> reviewIncident(
    String incidentId,
    String status,
  ) async {
    final id = Uri.encodeComponent(incidentId);

    return _asObject(
      await _request(
        'PATCH',
        '/admin/incidents/$id/review',
        authenticated: true,
        body: {
          'status': status,
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // ADMIN RECOVERY REQUESTS
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> requestIncidentRecovery(
    String incidentId,
    String reason,
  ) async {
    final id = Uri.encodeComponent(incidentId);

    return _asObject(
      await _request(
        'POST',
        '/admin/incidents/$id/recovery-request',
        authenticated: true,
        body: {
          'reason': reason.trim(),
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getAdminRecoveryRequests() async {
    return _asObjectList(
      await _request(
        'GET',
        '/admin/recovery-requests',
        authenticated: true,
      ),
    );
  }
  // ---------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> forgotPassword(
    String email,
  ) async {
    return _asObject(
      await _request(
        'POST',
        '/auth/forgot-password',
        body: {
          'email': email.trim().toLowerCase(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _asObject(
      await _request(
        'POST',
        '/auth/reset-password',
        body: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      ),
    );
  }
}
