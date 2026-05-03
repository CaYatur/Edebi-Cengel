// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web platformunda dart:html window.open ile URL'yi yeni sekmede açar.
/// url_launcher_web'in MissingPluginException sorununu devre dışı bırakır.
Future<bool> openUrlInBrowser(String url) async {
  html.window.open(url, '_blank');
  return true;
}
