// Türkçe alfabetik sıralama yardımcısı.
// Dart'ın varsayılan String.compareTo'su Unicode kod noktasına göre sıralar
// ve Ç, Ğ, İ, Ö, Ş, Ü gibi Türkçe karakterleri en sona atar. Bu yardımcı
// Türkçe alfabe sırasına göre karşılaştırma yapar:
// A B C Ç D E F G Ğ H I İ J K L M N O Ö P Q R S Ş T U Ü V W X Y Z

final Map<int, int> _turkishOrder = <String, int>{
  'A': 1, 'B': 2, 'C': 3, 'Ç': 4, 'D': 5, 'E': 6, 'F': 7,
  'G': 8, 'Ğ': 9, 'H': 10, 'I': 11, 'İ': 12, 'J': 13, 'K': 14,
  'L': 15, 'M': 16, 'N': 17, 'O': 18, 'Ö': 19, 'P': 20, 'Q': 21,
  'R': 22, 'S': 23, 'Ş': 24, 'T': 25, 'U': 26, 'Ü': 27, 'V': 28,
  'W': 29, 'X': 30, 'Y': 31, 'Z': 32,
}.map((k, v) => MapEntry(k.codeUnitAt(0), v));

String _turkishUpper(String s) {
  // Türkçeye uygun büyük harf dönüşümü (i -> İ, ı -> I).
  final buf = StringBuffer();
  for (final code in s.runes) {
    if (code == 'i'.codeUnitAt(0)) {
      buf.writeCharCode('İ'.codeUnitAt(0));
    } else if (code == 'ı'.codeUnitAt(0)) {
      buf.writeCharCode('I'.codeUnitAt(0));
    } else {
      buf.write(String.fromCharCode(code).toUpperCase());
    }
  }
  return buf.toString();
}

int compareTurkish(String a, String b) {
  final ua = _turkishUpper(a);
  final ub = _turkishUpper(b);
  final len = ua.length < ub.length ? ua.length : ub.length;
  for (int i = 0; i < len; i++) {
    final ca = ua.codeUnitAt(i);
    final cb = ub.codeUnitAt(i);
    if (ca == cb) continue;
    final wa = _turkishOrder[ca] ?? (1000 + ca);
    final wb = _turkishOrder[cb] ?? (1000 + cb);
    if (wa != wb) return wa - wb;
  }
  return ua.length - ub.length;
}
