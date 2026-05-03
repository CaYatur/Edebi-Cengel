// Platform bazlı URL açma yardımcısı.
// Web'de dart:html/window.open kullanır,
// diğer platformlarda url_launcher kullanır.
export 'url_helper_stub.dart' if (dart.library.html) 'url_helper_web.dart';
