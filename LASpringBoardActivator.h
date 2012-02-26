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
- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteBoolMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;

@end

