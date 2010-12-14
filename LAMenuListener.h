#import "libactivator.h"

@class UIAlertView;
__attribute__((visibility("hidden")))
@interface LAMenuListener : NSObject <LAListener> {
@private
	NSDictionary *configuration;
	NSDictionary *menus;
	UIWindow *alertWindow;
	UIActionSheet *currentActionSheet;
	NSArray *currentItems;
	LAEvent *currentEvent;
}

+ (LAMenuListener *)sharedMenuListener;

@end
