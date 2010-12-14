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
	NSData *imageData;
	NSData *imageData2x;
}

+ (LAMenuListener *)sharedMenuListener;

@end
