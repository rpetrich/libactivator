#import <UIKit/UIKit.h>

// Events

@interface LAEvent : NSObject {
@private
	NSString *_name;
	BOOL _handled;
}
+ (id)eventWithName:(NSString *)name;
- (id)initWithName:(NSString *)name;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, getter=isHandled) BOOL handled;

@end

extern NSString * const LAEventNameMenuPressAtSpringBoard;
extern NSString * const LAEventNameMenuPressDouble;
extern NSString * const LAEventNameMenuHoldShort;

extern NSString * const LAEventNameLockHoldShort;

extern NSString * const LAEventNameSpringBoardPinch;
extern NSString * const LAEventNameSpringBoardSpread;

extern NSString * const LAEventNameStatusBarSwipeRight;
extern NSString * const LAEventNameStatusBarSwipeLeft;
extern NSString * const LAEventNameStatusBarSwipeDown;
extern NSString * const LAEventNameStatusBarTapDouble;

// Activator

@protocol LAListener;

@interface LAActivator : NSObject {
@private
	NSMutableDictionary *_listeners;
	NSDictionary *_preferences;
}
+ (LAActivator *)sharedInstance;

- (id<LAListener>)listenerForEvent:(LAEvent *)event;
- (void)sendEventToListener:(LAEvent *)event;
- (void)sendAbortToListener:(LAEvent *)event;

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name;
- (void)unregisterListenerWithName:(NSString *)name;

- (void)reloadPreferences;

@end

// Listeners

@protocol LAListener <NSObject>
@required
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
@optional
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
@end

// Settings Controller

@interface LAListenerSettingsViewController : UIViewController {
@private
	NSString *_listenerName;
	NSArray *_events;
	NSMutableDictionary *_eventData;
	NSMutableDictionary *_preferences;	
}

- (id)init;
@property (nonatomic, copy) NSString *listenerName;

@end

