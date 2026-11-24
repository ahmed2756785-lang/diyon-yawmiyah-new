import 'package:flutter_test/flutter_test.dart';
import 'package:diyon_yawmiyah/main.dart';

void main() {
  testWidgets('تطبيق ديون يومية يعرض الصفحة الرئيسية', (tester) async {
    await tester.pumpWidget(const DiyonApp());
    expect(find.text('ديون يومية'), findsOneWidget);
  });
}
