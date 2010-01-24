#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>

@interface LAActivator ()
- (void)_loadPreferences;
- (void)_savePreferences;
- (void)_reloadPreferences;
- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject;
- (void)_addApplication:(SBApplication *)application;
- (void)_removeApplication:(SBApplication *)application;
- (NSDictionary *)_cachedAndSortedListeners;
@end

@interface LAApplicationListener : NSObject<LAListener> {
@private
	SBApplication *_application;
}
- (id)initWithApplication:(SBApplication *)application;
@end

@interface LARemoteListener : NSObject<LAListener> {
@private
	NSString *_listenerName;
	CPDistributedMessagingCenter *_messagingCenter;
}
- (id)initWithListenerName:(NSString *)listenerName;
@end

