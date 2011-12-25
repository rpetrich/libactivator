#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LARemoteListener : NSObject<LAListener>
+ (LARemoteListener *)sharedInstance;
@end
