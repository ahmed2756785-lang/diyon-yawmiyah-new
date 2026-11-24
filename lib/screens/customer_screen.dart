import 'package:flutter/material.dart';
import '../data/database.dart';
import 'ledger_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Future<List<Map<String, Object?>>> _future;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _load() => _future = AppDatabase.instance.customers();

  Future<void> _addCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('إضافة عميل جديد'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم العميل *')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظات')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
      ],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      await AppDatabase.instance.addCustomer(name.text, phone.text, note.text);
      if (mounted) setState(_load);
      widget.onChanged();
    }
    name.dispose(); phone.dispose(); note.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final query = _search.text.trim().toLowerCase();
        final list = all.where((c) => (c['name'] as String).toLowerCase().contains(query) ||
          (c['phone'] as String).contains(query)).toList();
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن عميل...'),
          )),
          Expanded(child: snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
              ? const Center(child: Text('لا توجد نتائج. أضف عميلاً جديداً.'))
              : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final c = list[index];
                  final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                  return Card(child: ListTile(
                    leading: CircleAvatar(child: Text((c['name'] as String).characters.first)),
                    title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text((c['phone'] as String?)?.isEmpty == true ? 'سجل العميل' : (c['phone'] as String? ?? '')),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(balance.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: balance > 0 ? Colors.red : Colors.green)),
                      const Text('الرصيد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerScreen(customer: c)));
                      if (mounted) setState(_load);
                      widget.onChanged();
                    },
                  ));
                },
              )),
        ]);
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addCustomer,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('إضافة عميل'),
    ),
  );
}
