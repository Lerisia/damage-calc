// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Web path: synthesise a Blob URL for the PNG and click a
/// generated <a download> element, which triggers the browser's
/// standard "save file" flow.
Future<void> savePartyImageBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
