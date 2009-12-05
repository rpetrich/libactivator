#import <Foundation/Foundation.h>

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

@protocol LAListener <NSObject>
@required
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event;
@optional
- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event;
@end

extern NSString * const LAEventNameMenuSinglePress;
extern NSString * const LAEventNameMenuDoublePress;
extern NSString * const LAEventNameMenuShortHold;

extern NSString * const LAEventNameLockShortHold;

extern NSString * const LAEventNameMenuSpringBoardPinch;
extern NSString * const LAEventNameMenuSpringBoardSpread;
