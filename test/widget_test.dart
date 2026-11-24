import 'package:flutter_test/flutter_test.dart';
import 'package:diyon_yawmiyah/utils/arabic_parser.dart';

void main() {
  test('يستخرج المبلغ من الأرقام العربية', () {
    expect(ArabicDebtParser.amountFrom('عليه ١٢٥٠ ريال'), 1250);
  });

  test('يتعرف على عبارة السداد', () {
    expect(ArabicDebtParser.isPayment('سدد أحمد ٥٠٠ ريال'), isTrue);
  });

  test('يتعرف على عبارة الدين', () {
    expect(ArabicDebtParser.isPayment('أضف دين ٢٠٠ ريال'), isFalse);
  });
}
