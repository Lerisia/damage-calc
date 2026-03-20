import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

Future<bool> saveImage(Uint8List bytes, String filename) async {
  final result = await ImageGallerySaverPlus.saveImage(
    bytes,
    quality: 100,
    name: filename,
  );
  return result != null;
}
