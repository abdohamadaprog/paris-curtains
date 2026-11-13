/// أدوات الأرقام العربية — مصدر واحد لكل التطبيق.
///
/// قبل كده كانت نفس الدالة مكررة في ٦ ملفات، وأي تعديل كان لازم يتعمل ٦ مرات.
library;

const String kArabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// تحويل أي أرقام لاتينية جوه النص لأرقام عربية مشرقية (٠١٢٣٤٥٦٧٨٩).
/// أي حاجة مش رقم بتفضل زي ما هي (الرموز، الحروف، الشرطة، إلخ).
String toArabicDigits(Object? value) {
  final s = (value ?? '').toString();
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = int.tryParse(ch);
    b.write(i == null ? ch : kArabicDigits[i]);
  }
  return b.toString();
}
