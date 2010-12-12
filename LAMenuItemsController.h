#import "libactivator.h"

@protocol LAMenuItemsControllerDelegate;

__attribute__((visibility("hidden")))
@interface LAMenuItemsController : LASettingsViewController {
@private
	NSMutableArray *_items;
	NSInteger destinationIndex;
}

@property (nonatomic, copy) NSArray *items;

@end
