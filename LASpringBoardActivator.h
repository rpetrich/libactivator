#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LASpringBoardActivator : LAActivator {
@private
	NSMutableDictionary *_listeners;
	NSMutableDictionary *_preferences;
	NSMutableDictionary *_eventData;
	NSDictionary *_cachedAndSortedListeners;
	int notify_token;
}

- (void)_eventModeChanged;

@end

