import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> saveImage(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$filename.png')
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
