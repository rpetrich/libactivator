#import "libactivator.h"

@class LAMenuListenerViewController;
__attribute__((visibility("hidden")))
@interface LAMenuListener : NSObject <LAListener> {
@private
	NSDictionary *menus;
	UIWindow *alertWindow;
	UIActionSheet *currentActionSheet;
	LAMenuListenerViewController *viewController;
	NSString *currentListenerName;
	NSArray *currentItems;
	LAEvent *currentEvent;
	NSData *imageData;
	NSData *imageData2x;
}

+ (LAMenuListener *)sharedMenuListener;

@end
