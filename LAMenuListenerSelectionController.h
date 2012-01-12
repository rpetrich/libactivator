#import "Settings.h"

__attribute__((visibility("hidden")))
@interface LAMenuListenerSelectionController : LASettingsViewController {
@private
	LAListenerTableViewDataSource *_dataSource;
	NSString *_selectedListenerName;
}

@property (nonatomic, copy) NSString *selectedListenerName;
@property (nonatomic, copy) NSSet *disallowedListenerNames;

@end
