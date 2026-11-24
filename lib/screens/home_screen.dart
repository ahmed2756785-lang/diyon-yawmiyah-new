import 'package:flutter/material.dart';
import '../data/database.dart';
import 'customer_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _refresh = 0;

  Future<void> _reload() async {
    if (mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ديون يومية', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('إدارة ديونك بسهولة', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [IconButton(
          tooltip: 'تحديث',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        )],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          Dashboard(key: ValueKey(_refresh), onChanged: _reload),
          CustomerScreen(key: ValueKey('customers$_refresh'), onChanged: _reload),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Future<Map<String, double>> _totals;
  late Future<List<Map<String, Object?>>> _customers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _totals = AppDatabase.instance.totals();
    _customers = AppDatabase.instance.customers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: _totals,
      builder: (context, snapshot) {
        final totals = snapshot.data ?? {'debts': 0.0, 'payments': 0.0};
        final balance = (totals['debts'] ?? 0) - (totals['payments'] ?? 0);
        return RefreshIndicator(
          onRefresh: () async { setState(_load); },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF176B5B), Color(0xFF248C74)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('إجمالي المبالغ المتبقية', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(_money(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _whiteMetric('إجمالي الديون', totals['debts'] ?? 0)),
                    Expanded(child: _whiteMetric('إجمالي السداد', totals['payments'] ?? 0)),
                  ]),
                ]),
              ),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('ملخص العملاء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: widget.onChanged, child: const Text('تحديث')),
              ]),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _customers,
                builder: (context, customers) {
                  if (customers.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
                  }
                  final list = customers.data ?? [];
                  if (list.isEmpty) return const _EmptyState();
                  return Column(children: list.take(6).map((c) {
                    final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                    return Card(child: ListTile(
                      leading: CircleAvatar(backgroundColor: const Color(0xFFE5F2EE), child: Text((c['name'] as String).characters.first)),
                      title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text((c['phone'] as String?)?.isEmpty == true ? 'بدون رقم هاتف' : (c['phone'] as String? ?? '')),
                      trailing: Text(_money(balance), style: TextStyle(fontWeight: FontWeight.bold, color: balance > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                    ));
                  }).toList());
                },
              ),
              const SizedBox(height: 12),
              const Text('أضف العملاء وسجّل الديون والمدفوعات من قسم العملاء.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  Widget _whiteMetric(String label, double amount) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    const SizedBox(height: 4),
    Text(_money(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
  ]);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 42),
    child: Column(children: [
      Icon(Icons.people_alt_outlined, size: 54, color: Color(0xFF9BB6AC)),
      SizedBox(height: 12),
      Text('لا يوجد عملاء حتى الآن', style: TextStyle(fontWeight: FontWeight.bold)),
      Text('ابدأ بإضافة أول عميل', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

String _money(double value) => '${value.toStringAsFixed(2)} ${appCurrency}';
