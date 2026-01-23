import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

class AccountStore extends ChangeNotifier {
  static const _accountsKey = 'dashboard_accounts';
  static const _activeKey = 'dashboard_active_account';
  static const String baseUrl = 'https://app.mycowbay.com';

  final List<AccountRecord> _accounts = [];
  String? _activeId;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<AccountRecord> get accounts => List.unmodifiable(_accounts);
  AccountRecord? get activeAccount {
    if (_accounts.isEmpty) return null;
    if (_activeId == null) return _accounts.first;
    for (final account in _accounts) {
      if (account.id == _activeId) return account;
    }
    return _accounts.first;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _accounts
          ..clear()
          ..addAll(decoded.map((item) => AccountRecord.fromJson(item as Map<String, dynamic>)));
      } catch (_) {
        _accounts.clear();
      }
    }
    _activeId = prefs.getString(_activeKey);
    if (_activeId == null && _accounts.isNotEmpty) {
      _activeId = _accounts.first.id;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setActive(String accountId) async {
    _activeId = accountId;
    await _persist();
    notifyListeners();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((item) => item.id == accountId);
    if (_activeId == accountId) {
      _activeId = _accounts.isNotEmpty ? _accounts.first.id : null;
    }
    await _persist();
    notifyListeners();
  }

  Future<AccountRecord> login({
    required String email,
    required String password,
  }) async {
    final api = DashboardApi(baseUrl: baseUrl, cookie: '');
    final result = await api.login(email: email, password: password);
    final account = AccountRecord(
      id: result.userId.isNotEmpty ? result.userId : email,
      email: email,
      cookie: result.cookie,
      baseUrl: baseUrl,
      createdAt: DateTime.now(),
    );
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(cookie: account.cookie);
    } else {
      _accounts.add(account);
    }
    _activeId = account.id;
    await _persist();
    notifyListeners();
    return account;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountsKey, jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    if (_activeId != null) {
      await prefs.setString(_activeKey, _activeId!);
    } else {
      await prefs.remove(_activeKey);
    }
  }
}
