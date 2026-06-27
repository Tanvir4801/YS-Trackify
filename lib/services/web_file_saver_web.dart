// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> webDownloadFile(
    String filename, List<int> bytes, String mimeType) async {
  final blob   = html.Blob([bytes], mimeType);
  final url    = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href          = url
    ..style.display = 'none'
    ..download      = filename;
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
