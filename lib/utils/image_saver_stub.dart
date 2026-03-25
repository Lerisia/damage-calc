import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<bool> saveImage(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename.png');
  await file.writeAsBytes(bytes);
  return true;
}

Future<bool> saveFile(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return true;
}
