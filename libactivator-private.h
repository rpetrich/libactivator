#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>
#import "SimulatorCompat.h"

// libactivator.m

@interface LAActivator ()

@property (nonatomic, readonly, getter=isAlive) BOOL alive;
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
@property (nonatomic, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, readonly) NSBundle *bundle;

@end

// Events.m

__attribute__((visibility("hidden")))
extern BOOL shouldAddNowPlayingButton;
__attribute__((visibility("hidden")))
extern CPDistributedMessagingCenter *messagingCenter;

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
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale;
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale;
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale;
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale;
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

@interface LASettingsViewController ()
+ (void)updateAdSettings;
@end


__attribute__((visibility("hidden")))
extern NSMutableDictionary *listenerBundles;
static inline NSBundle *ListenerBundle(NSString *listenerName) {
	if (!listenerBundles) {
		// Cache listener data
		listenerBundles = [[NSMutableDictionary alloc] init];
		NSString *listenersPath = SCRootPath(@"/Library/Activator/Listeners");
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:listenersPath error:NULL])
			if (![fileName hasPrefix:@"."])
				[listenerBundles setObject:[NSBundle bundleWithPath:[listenersPath stringByAppendingPathComponent:fileName]] forKey:fileName];
	}
	return [listenerBundles objectForKey:listenerName];
}
__attribute__((visibility("hidden")))
extern NSBundle *activatorBundle;

#ifdef DEBUG
#define Localize(bundle, key, value_) ({ \
	NSBundle *_bundle = (bundle); \
	NSString *_key = (key); \
	NSString *_value = (value_); \
	NSString *_result = (_bundle) ? [_bundle localizedStringForKey:_key value:_value table:nil] : _value; \
	NSLog(@"Activator: Localizing \"%@\" from \"%@\" with default value \"%@\"; result was \"%@\"", _key, _bundle, _value, _result); \
	_result; \
})
#else
#define Localize(bundle, key, value_) ({ \
	NSBundle *_bundle = (bundle); \
	NSString *_key = (key); \
	NSString *_value = (value_); \
	(_bundle) ? [_bundle localizedStringForKey:_key value:_value table:nil] : _value; \
})
#endif

__attribute__((always_inline))
static inline LAEvent *LASendEventWithName(NSString *eventName)
{
	LAEvent *event = [[[LAEvent alloc] initWithName:eventName mode:[LASharedActivator currentEventMode]] autorelease];
	[LASharedActivator sendEventToListener:event];
	return event;
}
