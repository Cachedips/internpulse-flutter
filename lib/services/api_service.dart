import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Exception khusus agar UI mudah menampilkan pesan error.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors; // validation errors Laravel (422)

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  /// Default base URL:
  /// - Web / Windows / macOS / Linux: http://127.0.0.1:8000/api
  /// - Android Emulator: http://10.0.2.2:8000/api
  /// - HP fisik: ganti dengan IP LAN laptop, mis. http://192.168.1.10:8000/api
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    } catch (_) {}
    return 'http://127.0.0.1:8000/api';
  }

  static String baseUrl = defaultBaseUrl;

  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _aiTimeout = Duration(
    seconds: 90,
  ); // Gemini bisa lambat

  String? _token;

  // ---------------------------------------------------------------------------
  // TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (hasToken) 'Authorization': 'Bearer $_token',
  };

  // ---------------------------------------------------------------------------
  // GENERIC HTTP METHODS
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? query,
    bool isAi = false,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: query);
    return _send(() => http.get(uri, headers: _headers), isAi: isAi);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool isAi = false,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _send(
      () => http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
      isAi: isAi,
    );
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _send(
      () => http.put(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _send(
      () => http.patch(uri, headers: _headers, body: jsonEncode(body ?? {})),
    );
  }

  Future<Map<String, dynamic>> delete(String endpoint) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _send(() => http.delete(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    bool isAi = false,
  }) async {
    try {
      final response = await request().timeout(isAi ? _aiTimeout : _timeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        'Tidak dapat terhubung ke server ($baseUrl). Pastikan backend Laravel menyala (php artisan serve). Detail: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Tidak dapat terhubung ke server ($baseUrl). Pastikan backend Laravel menyala. Detail: ${e.message}',
      );
    } on TimeoutException {
      throw ApiException('Koneksi timeout ke $baseUrl. Coba lagi beberapa saat.');
    } on FormatException {
      throw ApiException('Respon server tidak valid.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal terhubung ke $baseUrl: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message =
        (data['message'] as String?) ??
        'Terjadi kesalahan (${response.statusCode}).';
    throw ApiException(
      message,
      statusCode: response.statusCode,
      errors: data['errors'] is Map<String, dynamic> ? data['errors'] : null,
    );
  }

  // ---------------------------------------------------------------------------
  // AUTH & PROFILE
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? major,
    List<String> skills = const [],
  }) => post(
    '/register',
    body: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'major': major,
      'user_skills': skills,
    },
  );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => post('/login', body: {'email': email, 'password': password});

  Future<Map<String, dynamic>> logout() => post('/logout');

  Future<Map<String, dynamic>> getProfile() => get('/me');

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? major,
    List<String>? skills,
  }) => put(
    '/profile',
    body: {'name': ?name, 'major': ?major, 'user_skills': ?skills},
  );

  // ---------------------------------------------------------------------------
  // JOB FEED (Hybrid: Remotive + custom_jobs)
  // ---------------------------------------------------------------------------
  /// [location]: Surabaya | Jakarta | Remote | Luar Negeri
  /// [major]   : Informatika/SI | DKV | Manajemen/Pemasaran | Teknik Elektro, dll.
  Future<Map<String, dynamic>> getJobs({
    String? location,
    String? major,
    String? search,
    int page = 1,
  }) => get(
    '/jobs',
    query: {
      if (location != null && location.isNotEmpty) 'location': location,
      if (major != null && major.isNotEmpty) 'major': major,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
    },
  );

  /// Skill Gap Analyzer (Gemini).
  Future<Map<String, dynamic>> analyzeSkillGap({
    required String jobTitle,
    required String jobRequirements,
  }) => post(
    '/jobs/analyze',
    isAi: true,
    body: {'job_title': jobTitle, 'job_requirements': jobRequirements},
  );

  // ---------------------------------------------------------------------------
  // KANBAN TRACKER
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getTrackers() => get('/trackers');

  Future<Map<String, dynamic>> createTracker(Map<String, dynamic> data) =>
      post('/trackers', body: data);

  Future<Map<String, dynamic>> updateTracker(
    int id,
    Map<String, dynamic> data,
  ) => put('/trackers/$id', body: data);

  /// status: saved | applied | interview | accepted | rejected
  Future<Map<String, dynamic>> updateTrackerStatus(int id, String status) =>
      patch('/trackers/$id/status', body: {'status': status});

  Future<Map<String, dynamic>> deleteTracker(int id) => delete('/trackers/$id');

  // ---------------------------------------------------------------------------
  // AI FEATURES
  // ---------------------------------------------------------------------------
  /// [AI 1] Career Insight & Strategy Dashboard
  Future<Map<String, dynamic>> getCareerInsight() =>
      get('/trackers/insights', isAi: true);

  /// [AI 2] Follow-up Email Generator. type: email | linkedin
  Future<Map<String, dynamic>> generateFollowUp(
    int trackerId, {
    String type = 'email',
  }) => post('/trackers/$trackerId/followup', isAi: true, body: {'type': type});

  /// [AI 3] Interview Simulator
  Future<Map<String, dynamic>> startInterview(int trackerId) =>
      post('/trackers/$trackerId/interview/question', isAi: true);

  Future<Map<String, dynamic>> submitInterviewAnswer({
    required int trackerId,
    required String question,
    required String answer,
  }) => post(
    '/trackers/$trackerId/interview/answer',
    isAi: true,
    body: {'question': question, 'answer': answer},
  );

  /// [AI 4] PDF Report. Backend mengembalikan {"url": "..."} (signed URL sementara)
  /// lalu dibuka dengan url_launcher (karena header Bearer tidak bisa dikirim browser).
  Future<String> getReportPdfUrl() async {
    final res = await post('/trackers/report/pdf-link', isAi: true);
    final url = res['url'] as String?;
    if (url == null) throw ApiException('Link PDF tidak tersedia.');
    return url;
  }
}
