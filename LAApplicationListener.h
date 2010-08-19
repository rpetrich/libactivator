#import "libactivator.h"

@class SBApplication;

__attribute__((visibility("hidden")))
@interface LAApplicationListener : NSObject<LAListener> {
}

+ (id)sharedInstance;
- (BOOL)activateApplication:(SBApplication *)application;
- (SBApplication *)topApplication;

@end
