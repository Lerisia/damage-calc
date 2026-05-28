/// Cross-platform save entry point for the party-image export.
/// Conditional export keeps mobile/desktop builds from compiling
/// dart:html and web builds from compiling dart:io / package:gal.
export 'party_image_save_stub.dart'
    if (dart.library.io) 'party_image_save_io.dart'
    if (dart.library.html) 'party_image_save_web.dart';
