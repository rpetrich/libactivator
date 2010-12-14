#import "LAMenuListener.h"
#import "libactivator-private.h"

#import <UIKit/UIKit.h>

@interface LAMenuListener () <UIAlertViewDelegate>
- (void)unloadConfiguration;
- (void)refreshConfiguration;
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
	[currentItems release];
	currentAlertView.delegate = nil;
	[currentAlertView release];
	[currentEvent release];
	[self unloadConfiguration];
	[super dealloc];
}

- (void)unloadConfiguration
{
	for (NSString *menuKey in [menus allKeys])
		[LASharedActivator unregisterListenerWithName:menuKey];
	menus = nil;
	[configuration release];
	configuration = nil;
}

- (void)refreshConfiguration
{
	configuration = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/libactivator.menu.plist"];
	menus = [configuration objectForKey:@"menus"];
	for (NSString *menuKey in [menus allKeys])
		[LASharedActivator registerListener:self forName:menuKey ignoreHasSeen:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != alertView.cancelButtonIndex) {
		NSString *listenerName = [currentItems objectAtIndex:buttonIndex];
		[[LASharedActivator listenerForName:listenerName] activator:LASharedActivator receiveEvent:currentEvent forListenerName:listenerName];
	}
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	if (currentAlertView) {
		[currentAlertView dismissWithClickedButtonIndex:currentAlertView.cancelButtonIndex animated:YES];
		[currentAlertView release];
		currentAlertView = nil;
	} else {
		NSDictionary *menuData = [menus objectForKey:listenerName];
		UIAlertView *av = [[UIAlertView alloc] init];
		av.title = [menuData objectForKey:@"title"];
		NSMutableArray *compatibleItems = [[NSMutableArray alloc] init];
		for (NSString *item in [menuData objectForKey:@"items"]) {
			if ([LASharedActivator listenerWithName:item isCompatibleWithMode:event.mode]) {
				[compatibleItems addObject:item];
				[av addButtonWithTitle:[activator localizedTitleForListenerName:item] ?: @""];
			}
		}
		av.cancelButtonIndex = [av addButtonWithTitle:[activator localizedStringForKey:@"CANCEL" value:@"Cancel"]];
		av.delegate = self;
		[av show];
		currentAlertView = av;
		[currentEvent release];
		currentEvent = [event copy];
		[currentItems release];
		currentItems = compatibleItems;
		event.handled = YES;
	}
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[currentAlertView dismissWithClickedButtonIndex:currentAlertView.cancelButtonIndex animated:YES];
	[currentAlertView release];
	currentAlertView = nil;
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	if (currentAlertView) {
		[currentAlertView dismissWithClickedButtonIndex:currentAlertView.cancelButtonIndex animated:YES];
		[currentAlertView release];
		currentAlertView = nil;
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

@end
