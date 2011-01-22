#import "libactivator.h"

@class LAMenuListenerSelectionController;
@protocol LAMenuItemsControllerDelegate;

__attribute__((visibility("hidden")))
@interface LAMenuItemsController : LASettingsViewController {
@private
	NSMutableArray *_items;
	NSInteger destinationIndex;
	LAMenuListenerSelectionController *vc;
}


@property (nonatomic, copy) NSArray *items;

@end
