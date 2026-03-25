import 'dart:typed_data';
import 'image_saver_stub.dart'
    if (dart.library.html) 'image_saver_web.dart' as impl;

Future<bool> saveImage(Uint8List bytes, String filename) {
  return impl.saveImage(bytes, filename);
}

Future<bool> saveFile(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) {
  return impl.saveFile(bytes, filename, mimeType: mimeType);
}
