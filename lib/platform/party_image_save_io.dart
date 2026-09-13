import 'dart:typed_data';
import 'package:gal/gal.dart';

/// Mobile / desktop path: drop the rendered PNG into the user's
/// photo library / gallery via [Gal.putImageBytes]. iOS uses the
/// pre-declared NSPhotoLibraryAddUsageDescription in Info.plist;
/// Android uses scoped MediaStore on API 29+ and falls back to
/// WRITE_EXTERNAL_STORAGE on lower (declared in AndroidManifest).
Future<void> savePartyImageBytes(Uint8List bytes, String filename) async {
  await Gal.putImageBytes(bytes, name: filename);
}
