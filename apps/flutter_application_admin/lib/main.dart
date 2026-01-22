import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22577A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Mycowbay Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: GoogleFonts.spaceGroteskTextTheme(Theme.of(context).textTheme),
        cardTheme: const CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = const [
    OrdersView(),
    PlaceholderView(title: 'Links'),
    PlaceholderView(title: 'Members'),
    PlaceholderView(title: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.link), label: 'Links'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

class PlaceholderView extends StatelessWidget {
  final String title;

  const PlaceholderView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title view coming soon',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

enum OrderStatus { pending, paid, failed }

enum OrderStatusFilter { all, pending, paid, failed }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF4A261);
      case OrderStatus.paid:
        return const Color(0xFF2A9D8F);
      case OrderStatus.failed:
        return const Color(0xFFE76F51);
    }
  }
}

class Order {
  final String id;
  final String appName;
  final String linkCode;
  final String account;
  final String platform;
  final OrderStatus status;
  final int points;
  final double amount;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.appName,
    required this.linkCode,
    required this.account,
    required this.platform,
    required this.status,
    required this.points,
    required this.amount,
    required this.createdAt,
  });
}

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  OrderStatusFilter _filter = OrderStatusFilter.all;
  String _query = '';

  final List<Order> _orders = [
    Order(
      id: 'RG202601140001',
      appName: 'TATAO',
      linkCode: '3EE40466',
      account: 'me@example.com',
      platform: 'iOS',
      status: OrderStatus.pending,
      points: 30,
      amount: 990,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Order(
      id: 'RG202601140002',
      appName: 'Duo Runner',
      linkCode: '1A9F2C8D',
      account: 'ops@mycowbay.com',
      platform: 'Android',
      status: OrderStatus.paid,
      points: 10,
      amount: 300,
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    Order(
      id: 'RG202601140003',
      appName: 'SkyDesk',
      linkCode: '90ACB119',
      account: 'owner@mycowbay.com',
      platform: 'Android',
      status: OrderStatus.failed,
      points: 3,
      amount: 90,
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 20)),
    ),
    Order(
      id: 'RG202601140004',
      appName: 'TATAO',
      linkCode: '3EE40466',
      account: 'qa@mycowbay.com',
      platform: 'iOS',
      status: OrderStatus.paid,
      points: 30,
      amount: 990,
      createdAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 40)),
    ),
  ];

  List<Order> get _filteredOrders {
    return _orders.where((order) {
      if (_filter != OrderStatusFilter.all) {
        final statusMatch = switch (_filter) {
          OrderStatusFilter.pending => OrderStatus.pending,
          OrderStatusFilter.paid => OrderStatus.paid,
          OrderStatusFilter.failed => OrderStatus.failed,
          OrderStatusFilter.all => order.status,
        };
        if (order.status != statusMatch) {
          return false;
        }
      }

      if (_query.trim().isEmpty) {
        return true;
      }

      final q = _query.toLowerCase();
      return order.appName.toLowerCase().contains(q) ||
          order.linkCode.toLowerCase().contains(q) ||
          order.account.toLowerCase().contains(q) ||
          order.id.toLowerCase().contains(q);
    }).toList();
  }

  int get _pendingCount =>
      _orders.where((order) => order.status == OrderStatus.pending).length;

  int get _paidCount =>
      _orders.where((order) => order.status == OrderStatus.paid).length;

  int get _failedCount =>
      _orders.where((order) => order.status == OrderStatus.failed).length;

  int get _todayPoints => _orders.fold(0, (sum, order) => sum + order.points);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Orders Hub',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fast order handling and one-tap billing for admins.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      StatCard(
                        label: 'Pending',
                        value: '$_pendingCount',
                        accent: const Color(0xFFF4A261),
                      ),
                      StatCard(
                        label: 'Paid',
                        value: '$_paidCount',
                        accent: const Color(0xFF2A9D8F),
                      ),
                      StatCard(
                        label: 'Failed',
                        value: '$_failedCount',
                        accent: const Color(0xFFE76F51),
                      ),
                      StatCard(
                        label: 'Points Today',
                        value: '$_todayPoints',
                        accent: const Color(0xFF38BDF8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      QuickActionButton(
                        icon: Icons.flash_on,
                        label: 'Quick Bill',
                      ),
                      QuickActionButton(
                        icon: Icons.qr_code_scanner,
                        label: 'Scan Code',
                      ),
                      QuickActionButton(
                        icon: Icons.undo,
                        label: 'Refund',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search order, link, or account',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OrderStatusFilter.values.map((filter) {
                  final label = switch (filter) {
                    OrderStatusFilter.all => 'All',
                    OrderStatusFilter.pending => 'Pending',
                    OrderStatusFilter.paid => 'Paid',
                    OrderStatusFilter.failed => 'Failed',
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = _filteredOrders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(
                      order: order,
                      onTap: () => _showOrderDetails(context, order),
                    ),
                  );
                },
                childCount: _filteredOrders.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.appName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Order: ${order.id}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusPill(status: order.status),
                  const SizedBox(width: 10),
                  Text(order.platform),
                ],
              ),
              const SizedBox(height: 16),
              DetailRow(label: 'Account', value: order.account),
              DetailRow(label: 'Link code', value: order.linkCode),
              DetailRow(label: 'Points', value: '${order.points} pts'),
              DetailRow(label: 'Amount', value: '\$${order.amount.toStringAsFixed(0)}'),
              DetailRow(
                label: 'Created',
                value: order.createdAt.toLocal().toString().split('.').first,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.undo),
                      label: const Text('Refund'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check),
                      label: const Text('Mark Paid'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const QuickActionButton({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () {},
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.16),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
              width: 6,
              height: 120,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.appName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Link ${order.linkCode} • ${order.platform}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.account,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${order.points} pts',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.createdAt.toLocal().toString().split('.').first,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final OrderStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
