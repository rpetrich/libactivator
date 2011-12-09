#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LASimpleListener : NSObject<LAListener>
+ (LASimpleListener *)sharedInstance;

// System
- (BOOL)homeButton;
- (BOOL)sleepButton;
- (BOOL)respring;
- (BOOL)reboot;
- (BOOL)powerDown;
- (BOOL)spotlight;
- (BOOL)takeScreenshot;
- (BOOL)voiceControl;

// Lock Screen
- (BOOL)showLockScreen;
- (BOOL)dismissLockScreen;
- (BOOL)toggleLockScreen;

// iPod
- (BOOL)togglePlayback;
- (BOOL)previousTrack;
- (BOOL)nextTrack;
- (BOOL)musicControls;

@end
