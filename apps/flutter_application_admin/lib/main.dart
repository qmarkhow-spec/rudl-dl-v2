import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B4965),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Mycowbay Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: GoogleFonts.spaceGroteskTextTheme(Theme.of(context).textTheme),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final AuthStore _authStore = AuthStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _authStore.load().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _authStore,
      builder: (context, _) {
        if (_authStore.isLoggedIn) {
          return AdminHome(authStore: _authStore);
        }
        return LoginScreen(authStore: _authStore);
      },
    );
  }
}

class AuthStore extends ChangeNotifier {
  static const _tokenKey = 'admin_token';
  static const _fixedBaseUrl = 'https://app.mycowbay.com';

  String baseUrl = _fixedBaseUrl;
  String? token;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = _fixedBaseUrl;
    token = prefs.getString(_tokenKey);
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_fixedBaseUrl/api/admin/auth');
    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      return false;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['ok'] != true || payload['token'] == null) {
      return false;
    }

    baseUrl = _fixedBaseUrl;
    token = payload['token']?.toString();
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenKey, token!);
    }
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}

class AdminApi {
  final String baseUrl;
  final String token;
  final http.Client _client;

  AdminApi({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'accept': 'application/json',
        'authorization': 'Bearer $token',
      };

  Future<List<MemberRecord>> fetchMembers() async {
    final response = await _client.get(_uri('/api/admin/members'), headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException('Fetch members failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'Fetch members failed');
    }
    final list = (payload['members'] as List<dynamic>? ?? []);
    return list.map((raw) => MemberRecord.fromJson(raw as Map<String, dynamic>)).toList();
  }

  Future<List<DistributionLink>> fetchDistributions({int page = 1, int pageSize = 20}) async {
    final uri = _uri('/api/admin/links?page=$page&pageSize=$pageSize');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException('Fetch links failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'Fetch links failed');
    }
    final list = (payload['links'] as List<dynamic>? ?? []);
    return list.map((raw) => DistributionLink.fromJson(raw as Map<String, dynamic>)).toList();
  }

  Future<void> updateMemberBalance({
    required String memberId,
    double? setBalance,
    double? adjustBalance,
  }) async {
    final body = <String, dynamic>{};
    if (setBalance != null) body['setBalance'] = setBalance;
    if (adjustBalance != null) body['adjustBalance'] = adjustBalance;
    final response = await _client.patch(
      _uri('/api/admin/members/$memberId'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw ApiException('Update balance failed (${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'Update balance failed');
    }
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class MemberRecord {
  final String id;
  final String email;
  final String role;
  final double balance;
  final DateTime createdAt;

  const MemberRecord({
    required this.id,
    required this.email,
    required this.role,
    required this.balance,
    required this.createdAt,
  });

  factory MemberRecord.fromJson(Map<String, dynamic> json) {
    return MemberRecord(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '-',
      role: json['role']?.toString() ?? 'user',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (((json['createdAt'] as num?)?.toDouble() ?? 0) * 1000).toInt(),
        isUtc: true,
      ).toLocal(),
    );
  }
}

class DistributionLink {
  final String id;
  final String code;
  final String title;
  final String platform;
  final bool isActive;
  final int todayApkDownloads;
  final int todayIpaDownloads;
  final int todayTotalDownloads;
  final int totalDownloads;
  final String? apkVersion;
  final String? ipaVersion;
  final List<DistributionFile> files;

  const DistributionLink({
    required this.id,
    required this.code,
    required this.title,
    required this.platform,
    required this.isActive,
    required this.todayApkDownloads,
    required this.todayIpaDownloads,
    required this.todayTotalDownloads,
    required this.totalDownloads,
    required this.apkVersion,
    required this.ipaVersion,
    required this.files,
  });

  factory DistributionLink.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map((raw) => DistributionFile.fromJson(raw as Map<String, dynamic>))
        .toList();
    return DistributionLink(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      platform: json['platform']?.toString() ?? '',
      isActive: json['isActive'] == true || json['isActive'] == 1,
      todayApkDownloads: (json['todayApkDl'] as num?)?.toInt() ?? 0,
      todayIpaDownloads: (json['todayIpaDl'] as num?)?.toInt() ?? 0,
      todayTotalDownloads: (json['todayTotalDl'] as num?)?.toInt() ?? 0,
      totalDownloads: (json['totalTotalDl'] as num?)?.toInt() ?? 0,
      apkVersion: json['apkVersion']?.toString(),
      ipaVersion: json['ipaVersion']?.toString(),
      files: files,
    );
  }
}

class DistributionFile {
  final String id;
  final String platform;
  final String? version;

  const DistributionFile({
    required this.id,
    required this.platform,
    required this.version,
  });

  factory DistributionFile.fromJson(Map<String, dynamic> json) {
    return DistributionFile(
      id: json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      version: json['version']?.toString(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final AuthStore authStore;

  const LoginScreen({super.key, required this.authStore});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mycowbay Admin',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Login with your admin account to manage members and distributions.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Admin email'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Email required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Password required' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _handleLogin,
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await widget.authStore.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!ok) {
        setState(() => _error = 'Login failed, check credentials.');
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class AdminHome extends StatefulWidget {
  final AuthStore authStore;

  const AdminHome({super.key, required this.authStore});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final api = AdminApi(baseUrl: widget.authStore.baseUrl, token: widget.authStore.token!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mycowbay Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => widget.authStore.logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MembersScreen(api: api),
          DistributionsScreen(api: api, baseUrl: widget.authStore.baseUrl),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.group), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.link), label: 'Distributions'),
        ],
      ),
    );
  }
}

class MembersScreen extends StatefulWidget {
  final AdminApi api;

  const MembersScreen({super.key, required this.api});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MemberRecord> _members = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(() => setState(() => _query = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await widget.api.fetchMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reload() async => _loadMembers();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search member or email',
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _reload)
          else
            Builder(builder: (context) {
              final filtered = _members.where((member) {
                final q = _query.trim().toLowerCase();
                if (q.isEmpty) return true;
                return member.email.toLowerCase().contains(q) ||
                    member.id.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No members found.')),
                );
              }

              return Column(
                children: filtered.map((member) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MemberCard(
                      member: member,
                      onEdit: () => _openBalanceEditor(member),
                    ),
                  );
                }).toList(),
              );
            }),
        ],
      ),
    );
  }

  void _openBalanceEditor(MemberRecord member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return BalanceEditor(
          member: member,
          onSubmit: (setBalance, adjustBalance) async {
            try {
              await widget.api.updateMemberBalance(
                memberId: member.id,
                setBalance: setBalance,
                adjustBalance: adjustBalance,
              );
              if (mounted) {
                final nextBalance = () {
                  double value = member.balance;
                  if (setBalance != null) {
                    value = setBalance;
                  }
                  if (adjustBalance != null) {
                    value += adjustBalance;
                  }
                  return value;
                }();
                setState(() {
                  final index = _members.indexWhere((entry) => entry.id == member.id);
                  if (index >= 0) {
                    _members[index] = MemberRecord(
                      id: member.id,
                      email: member.email,
                      role: member.role,
                      balance: nextBalance,
                      createdAt: member.createdAt,
                    );
                  }
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Balance updated')));
                _reload();
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
        );
      },
    );
  }
}

class DistributionsScreen extends StatefulWidget {
  final AdminApi api;
  final String baseUrl;

  const DistributionsScreen({super.key, required this.api, required this.baseUrl});

  @override
  State<DistributionsScreen> createState() => _DistributionsScreenState();
}

class _DistributionsScreenState extends State<DistributionsScreen> {
  late Future<List<DistributionLink>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchDistributions(pageSize: 50);
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.fetchDistributions(pageSize: 50));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Distributions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DistributionLink>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return _ErrorCard(message: snapshot.error.toString(), onRetry: _reload);
              }
              final links = snapshot.data ?? [];
              if (links.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No distributions yet.')),
                );
              }
              return Column(
                children: links.map((link) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DistributionCard(link: link, baseUrl: widget.baseUrl),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final MemberRecord member;
  final VoidCallback onEdit;

  const MemberCard({super.key, required this.member, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFCBD5F5),
            child: Text(member.email.isNotEmpty ? member.email[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Role: ${member.role}  Balance: ${member.balance.toStringAsFixed(0)}'),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class DistributionCard extends StatelessWidget {
  final DistributionLink link;
  final String baseUrl;

  const DistributionCard({super.key, required this.link, required this.baseUrl});

  String _formatCount(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _buildDownloadUrl() {
    final sanitized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$sanitized/d/${link.code}';
  }

  String _resolveVersion({required bool apk}) {
    final direct = apk ? link.apkVersion : link.ipaVersion;
    if (direct != null && direct.trim().isNotEmpty) return direct;
    final platformHints = apk ? ['apk', 'android'] : ['ipa', 'ios'];
    for (final file in link.files) {
      final lower = file.platform.toLowerCase();
      if (platformHints.any((hint) => lower.contains(hint))) {
        if (file.version != null && file.version!.trim().isNotEmpty) {
          return file.version!;
        }
      }
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = link.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final downloadUrl = _buildDownloadUrl();
    final apkVersion = _resolveVersion(apk: true);
    final ipaVersion = _resolveVersion(apk: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 64,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Code: ${link.code}'),
                const SizedBox(height: 4),
                Text(
                  'Today downloads: ${_formatCount(link.todayTotalDownloads)} '
                  '(APK: ${_formatCount(link.todayApkDownloads)}, IPA: ${_formatCount(link.todayIpaDownloads)})',
                ),
                const SizedBox(height: 4),
                Text('APK v$apkVersion  •  IPA v$ipaVersion'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        downloadUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: downloadUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Link copied')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(link.isActive ? Icons.check_circle : Icons.cancel, color: statusColor),
        ],
      ),
    );
  }
}

class BalanceEditor extends StatefulWidget {
  final MemberRecord member;
  final Future<void> Function(double? setBalance, double? adjustBalance) onSubmit;

  const BalanceEditor({super.key, required this.member, required this.onSubmit});

  @override
  State<BalanceEditor> createState() => _BalanceEditorState();
}

class _BalanceEditorState extends State<BalanceEditor> {
  final _setController = TextEditingController();
  final _adjustController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _setController.dispose();
    _adjustController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.member.email, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Current balance: ${widget.member.balance.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          TextField(
            controller: _setController,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Set balance to'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adjustController,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Adjust balance by'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final setValue = double.tryParse(_setController.text.trim());
    final adjustValue = double.tryParse(_adjustController.text.trim());
    if (setValue == null && adjustValue == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter set or adjust value.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(setValue, adjustValue);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(message, style: const TextStyle(color: Color(0xFF991B1B))),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

