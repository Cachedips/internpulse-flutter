import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'api_service.dart';

/// Mengelola sesi login. Dipakai lewat Provider (ChangeNotifier).
class AuthService extends ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? _user;
  bool _initializing = true;
  bool _loading = false;
  String? _error;

  UserModel? get user => _user;
  bool get initializing => _initializing;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  /// Dipanggil sekali saat aplikasi dibuka: cek token tersimpan.
  Future<void> init() async {
    await _api.loadToken();
    if (_api.hasToken) {
      try {
        final res = await _api.getProfile();
        _user = UserModel.fromJson(_userMap(res));
      } on ApiException {
        await _api.clearToken();
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() async {
      final res = await _api.login(email: email, password: password);
      await _storeSession(res);
    });
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? major,
    List<String> skills = const [],
  }) {
    return _run(() async {
      final res = await _api.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        major: major,
        skills: skills,
      );
      await _storeSession(res);
    });
  }

  Future<bool> updateProfile({String? name, String? major, List<String>? skills}) {
    return _run(() async {
      final res = await _api.updateProfile(name: name, major: major, skills: skills);
      _user = UserModel.fromJson(_userMap(res));
    });
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {/* abaikan, token tetap dihapus lokal */}
    await _api.clearToken();
    _user = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  Future<void> _storeSession(Map<String, dynamic> res) async {
    final token = (res['token'] ??
            res['access_token'] ??
            (res['data'] is Map ? res['data']['token'] ?? res['data']['access_token'] : null))
        ?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Token tidak diterima dari server.');
    }
    await _api.saveToken(token);
    _user = UserModel.fromJson(_userMap(res));
  }

  Map<String, dynamic> _userMap(Map<String, dynamic> res) {
    if (res['user'] is Map<String, dynamic>) {
      return res['user'] as Map<String, dynamic>;
    }
    if (res['data'] is Map<String, dynamic>) {
      final data = res['data'] as Map<String, dynamic>;
      if (data['user'] is Map<String, dynamic>) {
        return data['user'] as Map<String, dynamic>;
      }
      return data;
    }
    return res;
  }

  Future<bool> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = _friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Ambil pesan validasi pertama dari Laravel (422) jika ada.
  String _friendlyMessage(ApiException e) {
    final errors = e.errors;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return e.message;
  }
}
