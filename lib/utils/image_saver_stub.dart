import 'dart:io';
import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> saveImage(Uint8List bytes, String filename) async {
  final result = await ImageGallerySaverPlus.saveImage(
    bytes,
    quality: 100,
    name: filename,
  );
  return result != null;
}

Future<bool> saveFile(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return true;
}
