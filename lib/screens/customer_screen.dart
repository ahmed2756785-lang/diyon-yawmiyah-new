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
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _future = AppDatabase.instance.customers();
  }

  Future<void> _addCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إضافة عميل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم العميل *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (!mounted || ok != true) return;
      if (name.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب اسم العميل أولاً')),
        );
        return;
      }

      await AppDatabase.instance.addCustomer(name.text, phone.text, note.text);
      if (!mounted) return;
      setState(_load);
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ العميل')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ العميل: $error')),
      );
    } finally {
      name.dispose();
      phone.dispose();
      note.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final query = _search.text.trim().toLowerCase();
            final list = all.where((c) {
              final customerName = (c['name'] as String).toLowerCase();
              final customerPhone = c['phone'] as String? ?? '';
              return customerName.contains(query) || customerPhone.contains(query);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث عن عميل...',
                    ),
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? Center(child: Text('تعذر تحميل العملاء: ${snapshot.error}'))
                          : list.isEmpty
                              ? const Center(child: Text('لا توجد نتائج. أضف عميلاً جديداً.'))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: list.length,
                                  itemBuilder: (context, index) {
                                    final c = list[index];
                                    final customerName = c['name'] as String;
                                    final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                                    return Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          child: Text(customerName.isEmpty ? '?' : customerName.characters.first),
                                        ),
                                        title: Text(
                                          customerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          (c['phone'] as String?)?.isEmpty == true
                                              ? 'سجل العميل'
                                              : (c['phone'] as String? ?? ''),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${balance.toStringAsFixed(2)} ${appCurrency}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: balance > 0 ? Colors.red : Colors.green,
                                              ),
                                            ),
                                            const Text('الرصيد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => LedgerScreen(customer: c)),
                                          );
                                          if (!mounted) return;
                                          setState(_load);
                                          widget.onChanged();
                                        },
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addCustomer,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة عميل'),
        ),
      );
}
