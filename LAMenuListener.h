#import "libactivator.h"

@class UIAlertView;
__attribute__((visibility("hidden")))
@interface LAMenuListener : NSObject <LAListener> {
@private
	NSDictionary *configuration;
	NSDictionary *menus;
	UIAlertView *currentAlertView;
	NSString *currentListenerName;
	LAEvent *currentEvent;
}

+ (LAMenuListener *)sharedMenuListener;

@end
