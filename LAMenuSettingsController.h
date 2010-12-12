#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LAMenuSettingsController : LASettingsViewController {
@private
	NSMutableDictionary *menus;
	NSMutableArray *sortedMenus;
	NSString *selectedMenu;
}
@end
