import 'dart:typed_data';

/// Stub used when neither dart:io nor dart:html is available. Should
/// never actually fire — the conditional export below picks one of
/// the real implementations on any real Flutter target.
Future<void> savePartyImageBytes(Uint8List bytes, String filename) async {
  throw UnsupportedError(
      'No party-image save implementation for this platform');
}
