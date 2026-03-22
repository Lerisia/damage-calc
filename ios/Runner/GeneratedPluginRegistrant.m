//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<image_gallery_saver_plus/ImageGallerySaverPlusPlugin.h>)
#import <image_gallery_saver_plus/ImageGallerySaverPlusPlugin.h>
#else
@import image_gallery_saver_plus;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [ImageGallerySaverPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"ImageGallerySaverPlusPlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
}

@end
