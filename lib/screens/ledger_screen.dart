import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../data/database.dart';
import '../utils/arabic_parser.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, required this.customer});
  final Map<String, Object?> customer;
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late Future<List<Map<String, Object?>>> _future;
  final _speech = stt.SpeechToText();
  bool _listening = false;
  int get _id => widget.customer['id'] as int;

  @override
  void initState() { super.initState(); _load(); }
  void _load() => _future = AppDatabase.instance.ledger(_id);

  Future<void> _entry({required bool payment, String? spoken}) async {
    final amount = TextEditingController(text: spoken == null ? '' : (ArabicDebtParser.amountFrom(spoken)?.toString() ?? ''));
    final note = TextEditingController(text: spoken ?? '');
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(payment ? 'تسجيل دفعة' : 'إضافة دين'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ *')),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'البيان / الملاحظات')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
      ],
    ));
    final value = double.tryParse(ArabicDebtParser.normalize(amount.text));
    if (ok == true && value != null && value > 0) {
      await AppDatabase.instance.addTransaction(_id, payment ? 'payment' : 'debt', value, note.text);
      if (mounted) setState(_load);
    } else if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً أكبر من صفر')));
    }
    amount.dispose(); note.dispose();
  }

  Future<void> _voiceEntry() async {
    final available = await _speech.initialize(
      onStatus: (status) { if (status == 'notListening' && mounted) setState(() => _listening = false); },
      onError: (_) { if (mounted) setState(() => _listening = false); },
    );
    if (!available) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التعرّف الصوتي غير متاح على هذا الجهاز')));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'ar',
      listenFor: const Duration(seconds: 20),
      onResult: (result) {
        if (!result.finalResult || !mounted) return;
        final words = result.recognizedWords;
        setState(() => _listening = false);
        _entry(payment: ArabicDebtParser.isPayment(words), spoken: words);
      },
    );
  }

  @override
  void dispose() { _speech.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.customer['name'] as String)),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _future,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        final debt = rows.where((r) => r['type'] == 'debt').fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
        final paid = rows.where((r) => r['type'] == 'payment').fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
        return Column(children: [
          Container(
            margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFE6F3EF), borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _summary('إجمالي الدين', debt, Colors.red.shade700),
              _summary('المدفوع', paid, Colors.green.shade700),
              _summary('المتبقي', debt - paid, const Color(0xFF176B5B)),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _entry(payment: false), icon: const Icon(Icons.add), label: const Text('إضافة دين'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _entry(payment: true), icon: const Icon(Icons.payments_outlined), label: const Text('تسجيل سداد'))),
          ])),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _listening ? null : _voiceEntry,
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            label: Text(_listening ? 'جارٍ الاستماع...' : 'إدخال صوتي بالعربية')),
          const Divider(height: 1),
          Expanded(child: rows.isEmpty
            ? const Center(child: Text('لا توجد حركات مسجلة لهذا العميل'))
            : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final isDebt = row['type'] == 'debt';
                final date = DateTime.tryParse(row['created_at'] as String? ?? '');
                return ListTile(
                  leading: CircleAvatar(backgroundColor: isDebt ? const Color(0xFFFFECEC) : const Color(0xFFE6F5EC),
                    child: Icon(isDebt ? Icons.arrow_upward : Icons.arrow_downward, color: isDebt ? Colors.red : Colors.green)),
                  title: Text(isDebt ? 'دين جديد' : 'دفعة مسددة'),
                  subtitle: Text('${date?.toLocal().toString().substring(0, 16) ?? ''}\n${row['note'] ?? ''}'),
                  isThreeLine: true,
                  trailing: Text('${isDebt ? '+' : '-'}${(row['amount'] as num).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDebt ? Colors.red : Colors.green)),
                );
              },
            )),
        ]);
      },
    ),
  );

  Widget _summary(String title, double amount, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    const SizedBox(height: 5),
    Text(amount.toStringAsFixed(2), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
  ]);
}
