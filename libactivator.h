#import <UIKit/UIKit.h>

// libactivator
// Centralized gestures and button management for iPhone OS

// Events

@interface LAEvent : NSObject {
@private
	NSString *_name;
	NSString *_mode;
	BOOL _handled;
}
+ (id)eventWithName:(NSString *)name;
+ (id)eventWithName:(NSString *)name mode:(NSString *)mode; // libactivator 1.1+
- (id)initWithName:(NSString *)name;
- (id)initWithName:(NSString *)name mode:(NSString *)mode; // libactivator 1.1+

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *mode; // libactivator 1.1+
@property (nonatomic, getter=isHandled) BOOL handled;

@end

// Activator

@protocol LAListener;

@interface LAActivator : NSObject {
@private
	NSMutableDictionary *_listeners;
	NSMutableDictionary *_preferences;
}
+ (LAActivator *)sharedInstance;

- (id<LAListener>)listenerForEvent:(LAEvent *)event;
- (void)sendEventToListener:(LAEvent *)event;
- (void)sendAbortToListener:(LAEvent *)event;

- (void)registerListener:(id<LAListener>)listener forName:(NSString *)name;
- (void)unregisterListenerWithName:(NSString *)name;

- (BOOL)hasSeenListenerWithName:(NSString *)name; // libactivator 1.0.1+

- (BOOL)assignEvent:(LAEvent *)event toListenerWithName:(NSString *)listenerName; // libactivator 1.1+
- (void)unassignEvent:(LAEvent *)event; // libactivator 1.1+
- (NSString *)assignedListenerNameForEvent:(LAEvent *)event; // libactivator 1.1+
- (NSArray *)eventsAssignedToListenerWithName:(NSString *)listenerName; // libactivator 1.1+

@property (nonatomic, readonly) NSArray *availableEventNames; // libactivator 1.0.1+
- (NSDictionary *)infoForEventWithName:(NSString *)name;
@property (nonatomic, readonly) NSArray *availableListenerNames; // libactivator 1.0.1+
- (NSDictionary *)infoForListenerWithName:(NSString *)name;

@property (nonatomic, readonly) NSArray *availableEventModes; // libactivator 1.0.1+
- (NSString *)currentEventMode; // libactivator 1.1+

@end

// Listeners

@protocol LAListener <NSObject>
@required
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
@optional
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event;
@end

// Settings Controller

@interface LAListenerSettingsViewController : UIViewController {
@private
	NSString *_listenerName;
	NSString *_eventMode;
	NSMutableDictionary *_events;
	NSMutableDictionary *_eventData;
}

- (id)init;
@property (nonatomic, copy) NSString *listenerName;
@property (nonatomic, copy) NSString *eventMode; // libactivator 1.1+

@end

extern NSString * const LAActivatorSettingsFilePath;


extern NSString * const LAEventModeAny; // libactivator 1.1+
extern NSString * const LAEventModeSpringBoard; // libactivator 1.1+
extern NSString * const LAEventModeApplication; // libactivator 1.1+
extern NSString * const LAEventModeLockScreen; // libactivator 1.1+


extern NSString * const LAEventNameMenuPressAtSpringBoard;
extern NSString * const LAEventNameMenuPressSingle;
extern NSString * const LAEventNameMenuPressDouble;
extern NSString * const LAEventNameMenuPressTriple; // libactivator 1.1+
extern NSString * const LAEventNameMenuHoldShort;

extern NSString * const LAEventNameLockHoldShort;
extern NSString * const LAEventNameLockPressDouble; // libactivator 1.1+

extern NSString * const LAEventNameSpringBoardPinch;
extern NSString * const LAEventNameSpringBoardSpread;

extern NSString * const LAEventNameStatusBarSwipeRight;
extern NSString * const LAEventNameStatusBarSwipeLeft;
extern NSString * const LAEventNameStatusBarSwipeDown;
extern NSString * const LAEventNameStatusBarTapDouble;
extern NSString * const LAEventNameStatusBarHold;

extern NSString * const LAEventNameVolumeDownUp; // libactivator 1.1+
extern NSString * const LAEventNameVolumeUpDown; // libactivator 1.1+

extern NSString * const LAEventNameSlideInFromBottom; // libactivator 1.1+
