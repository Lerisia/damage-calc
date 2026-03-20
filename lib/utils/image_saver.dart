import 'dart:typed_data';
import 'image_saver_stub.dart'
    if (dart.library.html) 'image_saver_web.dart' as impl;

Future<bool> saveImage(Uint8List bytes, String filename) {
  return impl.saveImage(bytes, filename);
}
