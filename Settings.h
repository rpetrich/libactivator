#import <UIKit/UIKit.h>
#define LA_SETTINGS_CONTROLLER(superclass) (API)

@protocol LASettingsViewControllerDelegate;

@interface LASettingsViewController : UIViewController {
@protected
	UITableView *_tableView;
	id<LASettingsViewControllerDelegate> _delegate;
	UINavigationController *_savedNavigationController;
}
@end

@interface LASettingsViewController (Internal) <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, assign) id<LASettingsViewControllerDelegate> delegate;
- (void)pushSettingsController:(LASettingsViewController *)controller;
@end

@protocol LASettingsViewControllerDelegate <NSObject>
- (void)settingsViewController:(LASettingsViewController *)settingsController shouldPushToChildController:(LASettingsViewController *)childController;
@end

typedef BOOL (*libhideIsHiddenFunction)(NSString *);

@interface LARootSettingsController : LASettingsViewController {
@protected
	void *libhide;
	libhideIsHiddenFunction libhideIsHidden;
}
@end

@interface LAModeSettingsController : LASettingsViewController {
@protected
	NSString *_eventMode;
	NSArray *_resolvedModes;
	NSMutableDictionary *_events;
	NSArray *_groups;
}
@end

@class ActivatorEventViewHeader;
@class LAListenerTableViewDataSource;

@interface LAEventSettingsController : LASettingsViewController {
@protected
	NSArray *_modes;
	NSMutableSet *_currentAssignments;
	NSString *_eventName;
	LAListenerTableViewDataSource *_dataSource;
	ActivatorEventViewHeader *_headerView;
	UISearchBar *_searchBar;
	UIView *_headerWrapper;
}
@end

@interface LAListenerSettingsViewController : LASettingsViewController {
@protected
	NSString *_listenerName;
	NSString *_eventMode;
	NSMutableDictionary *_events;
	NSMutableDictionary *_compatibleEvents;
	NSArray *_groups;
}
@end

#import "libactivator.h"
