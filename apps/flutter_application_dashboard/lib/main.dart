import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_store.dart';
import 'api.dart';
import 'file_cache.dart';
import 'package_metadata.dart';
import 'foreground_service.dart';
import 'http_client.dart' if (dart.library.html) 'http_client_web.dart';
import 'models.dart';
import 'notification_service.dart';
import 'upload_manager.dart';

const String kCnDownloadBase = 'https://cn-d.mycowbay.com';
const String kRuDownloadBase = 'https://ru-d.mycowbay.com';
final UploadManager uploadManager = UploadManager();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ForegroundService.init();
  await NotificationService.init();
  runApp(const DashboardApp());
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B4965),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'mycowbay dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F6FA),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  final AccountStore _store = AccountStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        if (!_store.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DashboardShell(store: _store, uploadManager: uploadManager);
      },
    );
  }
}

class DashboardShell extends StatefulWidget {
  final AccountStore store;
  final UploadManager uploadManager;

  const DashboardShell({super.key, required this.store, required this.uploadManager});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.uploadManager,
      builder: (context, _) {
        final account = widget.store.activeAccount;
        final upload = widget.uploadManager;
        return Scaffold(
          appBar: AppBar(
            title: const Text('mycowbay dashboard'),
            bottom: upload.isBusy
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: upload.current?.progress,
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${((upload.current?.progress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
            actions: [
              if (account != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      account.email,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              DistributionListScreen(
                key: ValueKey(account?.id ?? 'none'),
                account: account,
                uploadManager: widget.uploadManager,
              ),
              AccountsScreen(store: widget.store),
              UploadsScreen(manager: widget.uploadManager),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.list_alt), label: 'List'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Accounts'),
              NavigationDestination(icon: Icon(Icons.cloud_upload), label: 'Uploads'),
            ],
          ),
        );
      },
    );
  }
}

class AccountsScreen extends StatefulWidget {
  final AccountStore store;

  const AccountsScreen({super.key, required this.store});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.accounts;
    final activeId = widget.store.activeAccount?.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton.icon(
              onPressed: _openLoginDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No accounts yet. Add one to start.'),
            ),
          )
        else
          Column(
            children: accounts.map((account) {
              final isActive = account.id == activeId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isActive ? const Color(0xFFE7F0F7) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isActive ? const Color(0xFF1B4965) : const Color(0xFFE2E8F0),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    account.email,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B4965),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isActive)
                          OutlinedButton(
                            onPressed: () => widget.store.setActive(account.id),
                            child: const Text('Use'),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => widget.store.removeAccount(account.id),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _openLoginDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => LoginDialog(store: widget.store),
    );
  }
}

class LoginDialog extends StatefulWidget {
  final AccountStore store;

  const LoginDialog({super.key, required this.store});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Login'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.store.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class DistributionListScreen extends StatefulWidget {
  final AccountRecord? account;
  final UploadManager uploadManager;

  const DistributionListScreen({super.key, required this.account, required this.uploadManager});

  @override
  State<DistributionListScreen> createState() => _DistributionListScreenState();
}

class _DistributionListScreenState extends State<DistributionListScreen> {
  DashboardPage? _page;
  bool _loading = false;
  String? _error;
  int _pageNumber = 1;
  final int _pageSize = 10;
  StreamSubscription<UploadEvent>? _uploadSub;

  DashboardApi? get _api => widget.account == null
      ? null
      : DashboardApi(baseUrl: widget.account!.baseUrl, cookie: widget.account!.cookie);

  @override
  void initState() {
    super.initState();
    _load();
    _uploadSub = widget.uploadManager.events.listen((event) {
      if (event.type == UploadEventType.success &&
          widget.account?.id == event.job.account.id) {
        _load(page: _pageNumber);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Upload completed')));
        }
      }
      if (event.type == UploadEventType.failed &&
          widget.account?.id == event.job.account.id) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(event.job.error ?? 'Upload failed')));
        }
      }
    });
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    if (_api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api!.fetchDashboard(page: page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _page = data;
        _pageNumber = data.page;
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

  @override
  Widget build(BuildContext context) {
    if (widget.account == null) {
      return const Center(child: Text('Please add an account first.'));
    }

    final page = _page;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _load(page: _pageNumber),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Balance: ${page?.balance.toStringAsFixed(0) ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _loading ? null : _openCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                _ErrorCard(message: _error!, onRetry: () => _load(page: _pageNumber))
              else if (page == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (page.links.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No distributions yet.'),
                  ),
                )
              else
                Column(
                  children: page.links
                      .map(
                        (link) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DistributionCard(
                            link: link,
                            baseUrl: widget.account!.baseUrl,
                            onEdit: () => _openEdit(link),
                            onDelete: () => _confirmDelete(link),
                            onStats: () => _openStats(link),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (page != null) _PaginationBar(page: page, onNavigate: _load),
            ],
          ),
        ),
        if (_loading)
          const Align(
            alignment: Alignment.center,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Loading...'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openCreate() async {
    if (_api == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DistributionFormScreen(
          api: _api!,
          baseUrl: widget.account!.baseUrl,
          uploadManager: widget.uploadManager,
          account: widget.account!,
        ),
      ),
    );
    if (created == true) {
      _load(page: 1);
    }
  }

  Future<void> _openEdit(DashboardLink link) async {
    if (_api == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DistributionFormScreen(
          api: _api!,
          baseUrl: widget.account!.baseUrl,
          link: link,
          uploadManager: widget.uploadManager,
          account: widget.account!,
        ),
      ),
    );
    if (updated == true) {
      _load(page: _pageNumber);
    }
  }

  Future<void> _confirmDelete(DashboardLink link) async {
    if (_api == null) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete'),
            content: Text('Delete ${link.code}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await _api!.deleteDistribution(link.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      _load(page: 1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openStats(DashboardLink link) async {
    if (_api == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatsDialog(api: _api!, link: link),
    );
  }
}

class DistributionCard extends StatelessWidget {
  final DashboardLink link;
  final String baseUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStats;

  const DistributionCard({
    super.key,
    required this.link,
    required this.baseUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onStats,
  });

  String _shareUrl() {
    if (link.networkArea == 'CN') {
      return '$kCnDownloadBase/d/${link.code}';
    }
    if (link.networkArea == 'RU') {
      return '$kRuDownloadBase/d/${link.code}';
    }
    final sanitized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$sanitized/d/${link.code}';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'URL_LAUNCH_FAILED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _shareUrl();
    final statusColor = link.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
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
                    ],
                  ),
                ),
                Icon(link.isActive ? Icons.check_circle : Icons.cancel, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Tag(label: 'Lang: ${link.language}'),
                _Tag(label: 'Area: ${link.networkArea}'),
                _Tag(label: link.isActive ? 'Active' : 'Inactive'),
              ],
            ),
            const SizedBox(height: 10),
            if (link.files.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: link.files.map((file) {
                  final platform = file.platform.toUpperCase();
                  final version = file.version.isNotEmpty ? file.version : '-';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$platform • v$version • ${formatSize(file.size)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  );
                }).toList(),
              )
            else
              const Text('-', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 10),
            Text(
              'Today: ${formatCount(link.todayTotalDl)} '
              '(APK ${formatCount(link.todayApkDl)}, IPA ${formatCount(link.todayIpaDl)})',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${formatCount(link.totalTotalDl)} '
              '(APK ${formatCount(link.totalApkDl)}, IPA ${formatCount(link.totalIpaDl)})',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${formatDateTime(link.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      try {
                        await _openUrl(url);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Unable to open link')));
                        }
                      }
                    },
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Link copied')));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: onStats, child: const Text('Details')),
                OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final DashboardPage page;
  final Future<void> Function({int page}) onNavigate;

  const _PaginationBar({required this.page, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final totalPages = (page.total / page.pageSize).ceil().clamp(1, 9999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text('Page ${page.page} / $totalPages', style: const TextStyle(fontSize: 12))),
          IconButton(
            onPressed: page.page <= 1 ? null : () => onNavigate(page: page.page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: page.page >= totalPages ? null : () => onNavigate(page: page.page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
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

class UploadsScreen extends StatelessWidget {
  final UploadManager manager;

  const UploadsScreen({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final current = manager.current;
        final queue = manager.queue;
        final history = manager.history;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Upload Queue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final removed = await manager.clearCachedFiles();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cleared $removed cached file(s).')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear cache'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null) _UploadJobCard(job: current, title: 'Uploading now'),
            if (current == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No active uploads.'),
                ),
              ),
            if (queue.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...queue.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _UploadJobCard(job: job, title: 'Queued'),
                  )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: manager.clearHistory,
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No uploads yet.'),
                ),
              )
            else
              ...history.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _UploadJobCard(job: job, title: 'Completed'),
                  )),
          ],
        );
      },
    );
  }
}

class _UploadJobCard extends StatelessWidget {
  final UploadJob job;
  final String title;

  const _UploadJobCard({required this.job, required this.title});

  Color _statusColor() {
    switch (job.status) {
      case UploadJobStatus.success:
        return const Color(0xFF16A34A);
      case UploadJobStatus.failed:
        return const Color(0xFFDC2626);
      case UploadJobStatus.uploading:
        return const Color(0xFF2563EB);
      case UploadJobStatus.queued:
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusText() {
    switch (job.status) {
      case UploadJobStatus.success:
        return 'Success';
      case UploadJobStatus.failed:
        return 'Failed';
      case UploadJobStatus.uploading:
        return 'Uploading';
      case UploadJobStatus.queued:
      default:
        return 'Queued';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent =
        ((job.progress) * 100).clamp(0, 100).toStringAsFixed(0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusText(),
                    style: TextStyle(color: _statusColor(), fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Title: ${job.title.isEmpty ? '-' : job.title}'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: job.progress)),
                const SizedBox(width: 8),
                Text('$percent%', style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (job.error != null) ...[
              const SizedBox(height: 6),
              Text(job.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: job.files.map((file) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${file.platform.toUpperCase()} • ${file.fileName} • ${formatSize(file.size)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsDialog extends StatefulWidget {
  final DashboardApi api;
  final DashboardLink link;

  const StatsDialog({super.key, required this.api, required this.link});

  @override
  State<StatsDialog> createState() => _StatsDialogState();
}

class _StatsDialogState extends State<StatsDialog> {
  bool _loading = true;
  String? _error;
  StatsResponse? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 9));
      final data = await widget.api.fetchStats(
        linkId: widget.link.id,
        from: from,
        to: now,
      );
      if (!mounted) return;
      setState(() {
        _stats = data;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stats • ${widget.link.code}'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.red))
                : _buildStats(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _buildStats() {
    final stats = _stats;
    if (stats == null) {
      return const Text('No data');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total: ${stats.summary.total} (APK ${stats.summary.totalApk}, IPA ${stats.summary.totalIpa})'),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView(
            children: stats.points.map((point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${formatDate(point.bucket)}  •  ${point.total} (APK ${point.apk}, IPA ${point.ipa})',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class DistributionFormScreen extends StatefulWidget {
  final DashboardApi api;
  final DashboardLink? link;
  final String baseUrl;
  final UploadManager uploadManager;
  final AccountRecord account;

  const DistributionFormScreen({
    super.key,
    required this.api,
    required this.baseUrl,
    required this.uploadManager,
    required this.account,
    this.link,
  });

  @override
  State<DistributionFormScreen> createState() => _DistributionFormScreenState();
}

class _DistributionFormScreenState extends State<DistributionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bundleController;
  late final TextEditingController _apkController;
  late final TextEditingController _ipaController;
  String _language = 'en';
  String _networkArea = 'global';
  bool _isActive = true;
  bool _autofill = true;
  bool _submitting = false;
  String? _error;
  FileSelection? _apkFile;
  FileSelection? _ipaFile;
  PackageMetadata? _apkMeta;
  PackageMetadata? _ipaMeta;

  bool get _isEdit => widget.link != null;

  @override
  void initState() {
    super.initState();
    final link = widget.link;
    _titleController = TextEditingController(text: link?.title ?? '');
    _bundleController = TextEditingController(text: link?.bundleId ?? '');
    _apkController = TextEditingController(text: link?.apkVersion ?? '');
    _ipaController = TextEditingController(text: link?.ipaVersion ?? '');
    _language = link?.language ?? 'en';
    _networkArea = link?.networkArea ?? 'global';
    _isActive = link?.isActive ?? true;
    _apkMeta = null;
    _ipaMeta = null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bundleController.dispose();
    _apkController.dispose();
    _ipaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Distribution' : 'New Distribution'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bundleController,
              decoration: const InputDecoration(labelText: 'Bundle ID'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _apkController,
                    decoration: const InputDecoration(labelText: 'APK version'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ipaController,
                    decoration: const InputDecoration(labelText: 'IPA version'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'zh-TW', child: Text('繁體中文')),
                DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
              ],
              onChanged: (value) => setState(() => _language = value ?? 'en'),
              decoration: const InputDecoration(labelText: 'Language'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _networkArea,
              items: const [
                DropdownMenuItem(value: 'global', child: Text('Global')),
                DropdownMenuItem(value: 'CN', child: Text('China')),
                DropdownMenuItem(value: 'RU', child: Text('Russia')),
              ],
              onChanged: _isEdit ? null : (value) => setState(() => _networkArea = value ?? 'global'),
              decoration: const InputDecoration(labelText: 'Network area'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            SwitchListTile(
              title: const Text('Autofill from package'),
              value: _autofill,
              onChanged: (value) {
                setState(() => _autofill = value);
                if (value) {
                  _applyAutofill(_apkMeta, 'apk');
                  _applyAutofill(_ipaMeta, 'ipa');
                }
              },
            ),
            const SizedBox(height: 12),
            _buildFilePicker(
              label: 'APK file',
              selection: _apkFile,
              onPick: () => _pickFile('apk'),
              onClear: () => setState(() => _apkFile = null),
            ),
            const SizedBox(height: 12),
            _buildFilePicker(
              label: 'IPA file',
              selection: _ipaFile,
              onPick: () => _pickFile('ipa'),
              onClear: () => setState(() => _ipaFile = null),
            ),
            if (_isEdit && widget.link!.files.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Existing files:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...widget.link!.files.map((file) => Text(
                    '${file.platform.toUpperCase()} • v${file.version.isEmpty ? '-' : file.version} • ${formatSize(file.size)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  )),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker({
    required String label,
    required FileSelection? selection,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (selection != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selection.file.name} • ${formatSize(selection.file.size)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
                ],
              )
            else
              const Text('No file selected', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _submitting ? null : onPick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose file'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(String platform) async {
    final FileType pickerType;
    final List<String>? extensions;
    final bool isAndroid = !kIsWebClient && defaultTargetPlatform == TargetPlatform.android;
    if (platform == 'apk') {
      pickerType = FileType.custom;
      extensions = const ['apk'];
    } else if (kIsWebClient) {
      pickerType = FileType.custom;
      extensions = const ['ipa'];
    } else if (isAndroid) {
      pickerType = FileType.any;
      extensions = null;
    } else {
      pickerType = FileType.custom;
      extensions = const ['ipa'];
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: pickerType,
        allowedExtensions: extensions,
        withData: kIsWebClient,
        withReadStream: !kIsWebClient,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'File picker failed: ${error.message ?? error.code}');
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'File picker failed: $error');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (platform == 'ipa' && !kIsWebClient) {
      final lowerExt = (file.extension ?? '').toLowerCase();
      final lowerPath = (file.path ?? '').toLowerCase();
      final isIpa = lowerExt == 'ipa' || lowerPath.endsWith('.ipa');
      if (!isIpa) {
        if (!mounted) return;
        setState(() => _error = 'Please select an .ipa file.');
        return;
      }
    }
    if (kIsWebClient && file.bytes == null) {
      if (!mounted) return;
      setState(() => _error = 'File read failed');
      return;
    }
    final localInfo = kIsWebClient ? null : await cacheFile(file);
    if (!kIsWebClient && localInfo == null) {
      if (!mounted) return;
      setState(() => _error = 'File read failed. Please reselect the file.');
      return;
    }
    final selection = FileSelection(
      platform: platform,
      file: file,
      localPath: localInfo?.path,
      localSize: localInfo?.size ?? file.size,
    );
    setState(() {
      _error = null;
      if (platform == 'apk') {
        _apkFile = selection;
      } else {
        _ipaFile = selection;
      }
    });
    final path = selection.localPath ?? selection.file.path ?? '';
    if (path.isNotEmpty) {
      final meta = platform == 'apk'
          ? await ApkMetadataReader.read(path)
          : await readIpaMetadata(path);
      if (!mounted) return;
      setState(() {
        if (platform == 'apk') {
          _apkMeta = meta;
        } else {
          _ipaMeta = meta;
        }
      });
      _applyAutofill(meta, platform);
    }
  }

  void _applyAutofill(PackageMetadata? meta, String platform) {
    if (!_autofill || meta == null) return;
    final title = meta.title?.trim() ?? '';
    final bundleId = meta.bundleId?.trim() ?? '';
    final version = meta.version?.trim() ?? '';
    if (title.isNotEmpty) {
      _titleController.text = title;
    }
    if (bundleId.isNotEmpty) {
      _bundleController.text = bundleId;
    }
    if (version.isNotEmpty) {
      if (platform == 'apk') {
        _apkController.text = version;
      }
      if (platform == 'ipa') {
        _ipaController.text = version;
      }
    }
    setState(() {});
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _apkFile == null && _ipaFile == null) {
      setState(() => _error = 'Please select at least one file.');
      return;
    }
    if (_autofill) {
      final apkBundle = (_apkMeta?.bundleId ?? '').trim();
      final ipaBundle = (_ipaMeta?.bundleId ?? '').trim();
      if (apkBundle.isNotEmpty && ipaBundle.isNotEmpty && apkBundle != ipaBundle) {
        setState(() => _error = 'AUTOFILL_MISMATCH');
        return;
      }
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final selections = [
        if (_apkFile != null) _apkFile!,
        if (_ipaFile != null) _ipaFile!,
      ];

      final files = selections.map((selection) {
        final meta =
            selection.platform == 'apk' ? _apkMeta : _ipaMeta;
        return UploadFile(
          platform: selection.platform,
          fileName: selection.file.name,
          size: selection.localSize,
          bytes: kIsWebClient ? selection.file.bytes : null,
          path: selection.localPath ?? selection.file.path,
          stream: selection.localPath == null ? selection.file.readStream : null,
          metaTitle: meta?.title,
          metaBundleId: meta?.bundleId,
          metaVersion: meta?.version,
        );
      }).toList();

      final job = UploadJob(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        account: widget.account,
        isEdit: _isEdit,
        linkId: widget.link?.id,
        title: _titleController.text.trim(),
        bundleId: _bundleController.text.trim(),
        apkVersion: _apkController.text.trim(),
        ipaVersion: _ipaController.text.trim(),
        autofill: _autofill,
        lang: _language,
        isActive: _isActive,
        networkArea: _networkArea,
        files: files,
      );
      widget.uploadManager.enqueue(job);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload queued')));
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class FileSelection {
  final String platform;
  final PlatformFile file;
  final String? localPath;
  final int localSize;

  const FileSelection({
    required this.platform,
    required this.file,
    required this.localPath,
    required this.localSize,
  });
}
