#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>

// libactivator.m

@interface LAActivator ()

@property (nonatomic, readonly) NSString *settingsFilePath;

- (void)didReceiveMemoryWarning;

- (void)_resetPreferences;
- (id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(id)value forPreference:(NSString *)preference;

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen;

- (id)_performRemoteMessage:(SEL)selector withObject:(id)withObject;

- (NSDictionary *)_cachedAndSortedListeners;

@property (nonatomic, readonly) NSURL *moreActionsURL;
@property (nonatomic, readonly) NSURL *adPaneURL;

@end

__attribute__((visibility("hidden")))
@interface LASpringBoardActivator : LAActivator {
@private
	NSMutableDictionary *_listeners;
	NSMutableDictionary *_preferences;
	NSMutableDictionary *_eventData;
	NSDictionary *_cachedAndSortedListeners;
	int notify_token;
	BOOL waitingToWriteSettings;
}

- (void)_eventModeChanged;
- (NSDictionary *)_handleRemoteListenerMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;
- (NSDictionary *)_handleRemoteBoolMessage:(NSString *)message withUserInfo:(NSDictionary *)userInfo;

@end

__attribute__((visibility("hidden")))
@interface LARemoteListener : NSObject<LAListener> {
}

+ (LARemoteListener *)sharedInstance;

@end

__attribute__((visibility("hidden")))
@interface LADefaultEventDataSource : NSObject<LAEventDataSource> {
   NSMutableDictionary *_eventData;
}

+ (LADefaultEventDataSource *)sharedInstance;

- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;
- (BOOL)eventWithNameIsHidden:(NSString *)eventName;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode;

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

@interface NSObject(LAListener)
- (void)activator:(LAActivator *)activator didChangeToEventMode:(NSString *)eventMode;

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName;

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName;
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName;
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName;
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)name;
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name;
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName;
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName;
- (NSNumber *)activator:(LAActivator *)activator requiresIsCompatibleWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName;
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName;

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event;
@end

@interface NSObject (LAEventDataSource)
- (BOOL)eventWithNameIsHidden:(NSString *)eventName;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode;
@end

@interface LASettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, assign) id<LASettingsViewControllerDelegate> delegate;
- (void)pushSettingsController:(LASettingsViewController *)controller;
@end

@protocol LASettingsViewControllerDelegate <NSObject>
- (void)settingsViewController:(LASettingsViewController *)settingsController shouldPushToChildController:(LASettingsViewController *)childController;
@end

__attribute__((visibility("hidden")))
@interface LAWebSettingsController : LARootSettingsController<UIWebViewDelegate> {
@private
	UIActivityIndicatorView *_activityView;
	UIWebView *_webView;
}

- (void)loadURL:(NSURL *)url;

@end

__attribute__((visibility("hidden")))
@interface LAEventGroupSettingsController : LASettingsViewController {
@private
	NSArray *_modes;
	NSArray *_events;
	NSString *_groupName;
}

- (id)initWithModes:(NSArray *)modes events:(NSMutableArray *)events groupName:(NSString *)groupName;

@end


__attribute__((visibility("hidden")))
NSMutableDictionary *listenerData;
__attribute__((visibility("hidden")))
NSBundle *activatorBundle;

#define Localize(bundle, key, value_) ({ \
	NSBundle *_bundle = (bundle); \
	NSString *_key = (key); \
	NSString *_value = (value_); \
	(_bundle) ? [_bundle localizedStringForKey:_key value:_value table:nil] : _value; \
})
