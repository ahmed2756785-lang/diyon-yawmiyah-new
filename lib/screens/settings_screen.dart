import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _currencies = ['ر.ي', 'ر.س', '\$', 'د.إ', 'ج.م'];
  String _currency = 'ر.ي';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final value = await AppDatabase.instance.getCurrency();
    if (!mounted) return;
    setState(() {
      _currency = _currencies.contains(value) ? value : 'ر.ي';
      _loading = false;
    });
  }

  Future<void> _setCurrency(String? value) async {
    if (value == null) return;
    await AppDatabase.instance.setCurrency(value);
    if (mounted) setState(() => _currency = value);
  }

  Future<void> _backup(BuildContext context) async {
    try {
      final data = await AppDatabase.instance.exportAll();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/diyon-yawmiyah-backup.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من ديون يومية');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء النسخة: $e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('استعادة نسخة احتياطية'),
      content: const Text('سيتم استبدال البيانات الحالية بالبيانات الموجودة في الملف. هل تريد المتابعة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
      ],
    ));
    if (confirm != true || !context.mounted) return;
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      final path = picked.files.single.path;
      final content = bytes != null ? utf8.decode(bytes) : await File(path!).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) throw const FormatException('تنسيق الملف غير صحيح');
      await AppDatabase.instance.importAll(decoded);
      await _loadCurrency();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت الاستعادة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('العملة المستخدمة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.currency_exchange), labelText: 'اختر العملة'),
            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: _loading ? null : _setCurrency,
          ),
          const SizedBox(height: 6),
          const Text('يتم حفظ اختيار العملة ضمن النسخة الاحتياطية.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      )),
      Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.backup_outlined)),
        title: const Text('إنشاء نسخة احتياطية'),
        subtitle: const Text('حفظ العملاء والديون والمدفوعات والإعدادات في ملف JSON'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => _backup(context),
      )),
      Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.restore)),
        title: const Text('استعادة نسخة احتياطية'),
        subtitle: const Text('استيراد ملف JSON سابق'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => _restore(context),
      )),
      const SizedBox(height: 24),
      const Center(child: Text('ديون يومية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      const Center(child: Text('الإصدار 1.0.0', style: TextStyle(color: Colors.grey))),
      const SizedBox(height: 12),
      const Text('بياناتك محفوظة محلياً على جهازك. احتفظ بنسخة احتياطية في مكان آمن.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
    ],
  );
}
