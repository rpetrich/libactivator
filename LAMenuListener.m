#import "LAMenuListener.h"
#import "libactivator-private.h"

#import <UIKit/UIKit.h>

@interface LAMenuListener () <UIActionSheetDelegate>
- (void)unloadConfiguration;
- (void)refreshConfiguration;
@end

@interface UIDevice (OS32)
- (BOOL)isWildcat;
@end

@interface UIActionSheet (OS32)
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
@end

@implementation LAMenuListener

static LAMenuListener *sharedMenuListener;

+ (void)initialize
{
	sharedMenuListener = [[LAMenuListener alloc] init];
}

+ (LAMenuListener *)sharedMenuListener
{
	return sharedMenuListener;
}

static void NotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[(LAMenuListener *)observer refreshConfiguration];
}

- (id)init
{
	if ((self = [super init])) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, NotificationCallback, CFSTR("libactivator.menu/settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		[self refreshConfiguration];
	}
	return self;
}

- (void)dealloc
{
	CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, CFSTR("libactivator.menu/settingschanged"), NULL);
	[imageData2x release];
	[imageData release];
	[currentItems release];
	currentActionSheet.delegate = nil;
	[currentActionSheet release];
	[currentEvent release];
	[self unloadConfiguration];
	[super dealloc];
}

- (void)unloadConfiguration
{
	if (LASharedActivator.runningInsideSpringBoard)
		for (NSString *menuKey in [menus allKeys])
			[LASharedActivator unregisterListenerWithName:menuKey];
	menus = nil;
	[configuration release];
	configuration = nil;
}

- (void)refreshConfiguration
{
	[self unloadConfiguration];
	configuration = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/libactivator.menu.plist"];
	menus = [configuration objectForKey:@"menus"];
	if (LASharedActivator.runningInsideSpringBoard)
		for (NSString *menuKey in [menus allKeys])
			[LASharedActivator registerListener:self forName:menuKey ignoreHasSeen:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != actionSheet.cancelButtonIndex) {
		NSString *listenerName = [currentItems objectAtIndex:buttonIndex];
		if (![LASharedActivator isDangerousToSendEvents])
			[[LASharedActivator listenerForName:listenerName] activator:LASharedActivator receiveEvent:currentEvent forListenerName:listenerName];
	}
}

- (void)cleanup
{
	[currentActionSheet release];
	currentActionSheet = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	alertWindow.hidden = YES;
	[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	if (currentActionSheet) {
		[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
		[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
	} else {
		NSDictionary *menuData = [menus objectForKey:listenerName];
		UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
		actionSheet.title = [menuData objectForKey:@"title"];
		NSMutableArray *compatibleItems = [[NSMutableArray alloc] init];
		for (NSString *item in [menuData objectForKey:@"items"]) {
			if ([LASharedActivator listenerWithName:item isCompatibleWithMode:event.mode]) {
				[compatibleItems addObject:item];
				[actionSheet addButtonWithTitle:[activator localizedTitleForListenerName:item] ?: @""];
			}
		}
		actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:[activator localizedStringForKey:@"CANCEL" value:@"Cancel"]];
		actionSheet.delegate = self;
		if (!alertWindow) {
			alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
			alertWindow.windowLevel = UIWindowLevelStatusBar;
		}
		alertWindow.hidden = NO;
		if ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat]) {
			CGRect bounds = alertWindow.bounds;
			if (![event.name hasPrefix:@"libactivator.statusbar."])
				bounds.origin.y += bounds.size.height;
			bounds.size.height = 0.0f;
			[actionSheet showFromRect:bounds inView:alertWindow animated:YES];
		} else {
			[actionSheet showInView:alertWindow];
		}
		currentActionSheet = actionSheet;
		[currentEvent release];
		currentEvent = [event copy];
		[currentItems release];
		currentItems = compatibleItems;
		event.handled = YES;
	}
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
	[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	if (currentActionSheet) {
		[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
		[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
		event.handled = YES;
	}
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	NSDictionary *menuData = [menus objectForKey:listenerName];
	return [menuData objectForKey:@"title"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return [activator localizedStringForKey:@"MENUS" value:@"Menus"];
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	if (scale && (*scale == 2.0f)) {
		if (!imageData2x)
			imageData2x = [[NSData dataWithContentsOfMappedFile:@"/System/Library/PreferenceBundles/LibActivator.bundle/icon@2x.png"] retain];
		return imageData2x;
	} else {
		if (!imageData)
			imageData = [[NSData dataWithContentsOfMappedFile:@"/System/Library/PreferenceBundles/LibActivator.bundle/icon.png"] retain];
		return imageData;
	}
}

@end
