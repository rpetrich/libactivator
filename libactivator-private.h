#import "libactivator.h"

#import <SpringBoard/SpringBoard.h>
#import <AppSupport/AppSupport.h>
#import "SimulatorCompat.h"

// libactivator.m

extern NSString * const LAEventNameSlideInFromLeftTop;
extern NSString * const LAEventNameSlideInFromLeftBottom;
extern NSString * const LAEventNameSlideInFromRightTop;
extern NSString * const LAEventNameSlideInFromRightBottom;

extern NSString * const LAEventNameTwoFingerSlideInFromLeftTop;
extern NSString * const LAEventNameTwoFingerSlideInFromLeftBottom;
extern NSString * const LAEventNameTwoFingerSlideInFromRightTop;
extern NSString * const LAEventNameTwoFingerSlideInFromRightBottom;

@interface LAActivator ()

@property (nonatomic, readonly, getter=isAlive) BOOL alive;
@property (nonatomic, readonly) NSString *settingsFilePath;

- (void)didReceiveMemoryWarning;

- (void)_resetPreferences;
- (id)_getObjectForPreference:(NSString *)preference;
- (void)_setObject:(id)value forPreference:(NSString *)preference;

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name ignoreHasSeen:(BOOL)ignoreHasSeen;

- (NSDictionary *)_cachedAndSortedListeners;
- (void)_cacheAllListenerMetadata;

- (UIImage *)cachedSmallIconForListenerName:(NSString *)listenerName;

- (NSInteger)_activeTouchCount;
- (void)_deferReceiveEventUntilTouchesComplete:(LAEvent *)event listenerName:(NSString *)listenerName;

@property (nonatomic, readonly) NSURL *moreActionsURL;
@property (nonatomic, readonly) NSURL *adPaneURL;
@property (nonatomic, readonly) NSBundle *bundle;

@end

// Events.m

__attribute__((visibility("hidden")))
extern BOOL shouldAddNowPlayingButton;
__attribute__((visibility("hidden")))
extern CFMessagePortRef serverPort;

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
	NSBundle *result = [listenerBundles objectForKey:listenerName];
	if (!result) {
		NSString *path = [SCRootPath(@"/Library/Activator/Listeners") stringByAppendingPathComponent:listenerName];
		result = [NSBundle bundleWithPath:path];
		if (result) {
			if (!listenerBundles)
				listenerBundles = [[NSMutableDictionary alloc] init];
			[listenerBundles setObject:result forKey:listenerName];
		}
	}
	return result;
}
__attribute__((visibility("hidden")))
extern NSMutableDictionary *listenerDictionaries;
static inline NSDictionary *ListenerDictionary(NSString *listenerName) {
	NSDictionary *result = [listenerDictionaries objectForKey:listenerName];
	if (result)
		return result;
	if (!listenerDictionaries) {
		listenerDictionaries = [[NSMutableDictionary alloc] initWithContentsOfFile:SCRootPath(@"/Library/Activator/Listeners/bundled.plist")];
		result = [listenerDictionaries objectForKey:listenerName];
		if (result)
			return result;
	}
	result = [ListenerBundle(listenerName) infoDictionary];
	if (result)
		[listenerDictionaries setObject:result forKey:listenerName];
	return result;
}
static inline id ListenerDictionaryValue(NSString *listenerName, NSString *key) {
	return [ListenerDictionary(listenerName) objectForKey:key];
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

@interface UIImage (UIApplicationIconPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(NSInteger)format scale:(CGFloat)scale;
@end
