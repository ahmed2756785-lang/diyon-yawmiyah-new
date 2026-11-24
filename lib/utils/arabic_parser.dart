class ArabicDebtParser {
  static const Map<String, String> _digits = {
    '٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9',
    '۰':'0','۱':'1','۲':'2','۳':'3','۴':'4','۵':'5','۶':'6','۷':'7','۸':'8','۹':'9',
  };

  static String normalize(String input) {
    var value = input;
    _digits.forEach((key, digit) => value = value.replaceAll(key, digit));
    return value.replaceAll('٬', '').replaceAll('٫', '.').replaceAll(',', '.');
  }

  static double? amountFrom(String input) {
    final text = normalize(input);
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  static bool isPayment(String input) {
    final text = input.replaceAll('أ', 'ا').replaceAll('إ', 'ا');
    return text.contains('سدد') || text.contains('دفع') ||
        text.contains('تسديد') || text.contains('استلم');
  }
}
