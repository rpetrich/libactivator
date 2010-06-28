#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LAToggleListener : NSObject<LAListener> {
}

+ (id)sharedInstance;

@end
