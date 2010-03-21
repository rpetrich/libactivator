#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>

// libactivator.m

@interface LAActivator ()

- (void)_loadPreferences;
- (void)_savePreferences;
- (void)_reloadPreferences;
- (id)_getObjectForPreference:(NSString *)preference;

- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject;
- (void)_addApplication:(SBApplication *)application;
- (void)_removeApplication:(SBApplication *)application;
- (BOOL)_activateApplication:(SBApplication *)application;
- (NSDictionary *)_cachedAndSortedListeners;
- (void)_eventModeChanged;

@end

__attribute__((visibility("hidden")))
@interface LAApplicationListener : NSObject<LAListener> {
@private
	SBApplication *_application;
}

- (id)initWithApplication:(SBApplication *)application;

@end

__attribute__((visibility("hidden")))
@interface LARemoteListener : NSObject<LAListener> {
@private
	NSString *_listenerName;
	CPDistributedMessagingCenter *_messagingCenter;
}

- (id)initWithListenerName:(NSString *)listenerName;

@end

// Events.m

__attribute__((visibility("hidden")))
@interface LASlideGestureWindow : UIWindow {
@private
	BOOL hasSentSlideEvent;
	NSString *_eventName;
}

+ (LASlideGestureWindow *)leftWindow;
+ (LASlideGestureWindow *)middleWindow;
+ (LASlideGestureWindow *)rightWindow;
+ (void)updateVisibility;

- (id)initWithFrame:(CGRect)frame eventName:(NSString *)eventName;

- (void)updateVisibility;

@end

__attribute__((visibility("hidden")))
@interface LAVolumeTapWindow : UIWindow {
}

@end

__attribute__((visibility("hidden")))
@interface LAQuickDoDelegate : NSObject {
@private
	BOOL hasSentSlideEvent;
}

+ (id)sharedInstance;

- (void)acceptEventsFromControl:(UIControl *)control;

@end

__attribute__((visibility("hidden")))
BOOL shouldAddNowPlayingButton;


#define SBWPreActivateDisplayStack        (SBDisplayStack *)[displayStacks objectAtIndex:0]
#define SBWActiveDisplayStack             (SBDisplayStack *)[displayStacks objectAtIndex:1]
#define SBWSuspendingDisplayStack         (SBDisplayStack *)[displayStacks objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack (SBDisplayStack *)[displayStacks objectAtIndex:3]
__attribute__((visibility("hidden")))
NSMutableArray *displayStacks;
