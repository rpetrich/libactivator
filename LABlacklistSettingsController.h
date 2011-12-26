#import "Settings.h"

__attribute__((visibility("hidden")))
@interface LABlacklistSettingsController : LASettingsViewController {
@private
	NSString *systemAppsTitle;
	NSArray *systemApps;
	NSString *userAppsTitle;
	NSArray *userApps;
}
@end
