#import "libactivator.h"

@class LAMenuItemsController;

__attribute__((visibility("hidden")))
@interface LAMenuSettingsController : LASettingsViewController {
@private
	NSMutableDictionary *menus;
	NSMutableArray *sortedMenus;
	NSString *selectedMenu;
	LAMenuItemsController *vc;
}
@end
