#import "LAMenuListener.h"
#import "libactivator-private.h"

#import <UIKit/UIKit2.h>

@interface LAMenuListener () <UIActionSheetDelegate>
- (void)unloadConfiguration;
- (void)refreshConfiguration;
@end

@interface UIDevice (OS32)
- (BOOL)isWildcat;
@end

@interface UIActionSheet (OS32)
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;
- (id)addMediaButtonWithTitle:(NSString *)title iconView:(UIImageView *)imageView andTableIconView:(UIImageView *)imageView;
@end

@interface UIViewController (Private)
@property (nonatomic, assign, readwrite) UIInterfaceOrientation interfaceOrientation;
@end

__attribute__((visibility("hidden")))
@interface LAMenuListenerViewController : UIViewController
@property (nonatomic, assign) BOOL allowAllOrientations;
@end

@implementation LAMenuListenerViewController

@synthesize allowAllOrientations;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return allowAllOrientations;
}

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
		NSDictionary *legacyConfiguration = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/libactivator.menu.plist"];
		if (legacyConfiguration) {
			[LASharedActivator _setObject:[legacyConfiguration objectForKey:@"menus"] forPreference:@"LAMenuSettings"];
			unlink("/var/mobile/Library/Preferences/libactivator.menu.plist");
		}
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
	[currentListenerName release];
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
	[menus release];
	menus = nil;
}

- (void)refreshConfiguration
{
	[self unloadConfiguration];
	menus = [[LASharedActivator _getObjectForPreference:@"LAMenuSettings"] retain];
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
	if (currentActionSheet && [listenerName isEqualToString:currentListenerName]) {
		[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
		[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
	} else {
		[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
		NSDictionary *menuData = [menus objectForKey:listenerName];
		UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
		actionSheet.title = [menuData objectForKey:@"title"];
		NSMutableArray *compatibleItems = [[NSMutableArray alloc] init];
		BOOL respondsToAddMediaButton = [actionSheet respondsToSelector:@selector(addMediaButtonWithTitle:iconView:andTableIconView:)];
		for (NSString *item in [menuData objectForKey:@"items"]) {
			if ([LASharedActivator listenerWithName:item isCompatibleWithMode:event.mode]) {
				[compatibleItems addObject:item];
				NSString *title = [activator localizedTitleForListenerName:item] ?: @"";
				UIImage *image;
				if (respondsToAddMediaButton && (image = [activator smallIconForListenerName:item])) {
					UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
					[actionSheet addMediaButtonWithTitle:title iconView:imageView andTableIconView:imageView];
					[imageView release];
				} else {
					[actionSheet addButtonWithTitle:title];
				}
			}
		}
		UIInterfaceOrientation currentOrientation = [UIApp statusBarOrientation];
		actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:[activator localizedStringForKey:@"CANCEL" value:@"Cancel"]];
		actionSheet.delegate = self;
		if (!alertWindow) {
			alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
			alertWindow.windowLevel = 1050.1f /*UIWindowLevelStatusBar*/;
		}
		alertWindow.hidden = NO;
		if (!viewController)
			viewController = [[LAMenuListenerViewController alloc] init];
		viewController.allowAllOrientations = YES;
		UIView *view = viewController.view;
		if ([alertWindow respondsToSelector:@selector(setRootViewController:)])
			[alertWindow setRootViewController:viewController];
		else
			[alertWindow addSubview:view];
		if ([alertWindow respondsToSelector:@selector(_updateToInterfaceOrientation:animated:)])
			[alertWindow _updateToInterfaceOrientation:[(SpringBoard *)UIApp _frontMostAppOrientation] animated:NO];
		if ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat]) {
			CGRect bounds = view.bounds;
			NSString *eventName = event.name;
			if ([eventName isEqualToString:LAEventNameSlideInFromLeft]) {
				bounds.size.width = 1.0f;
			} else if ([eventName isEqualToString:LAEventNameSlideInFromRight]) {
				bounds.origin.x += bounds.size.width;
				bounds.size.width = 1.0f;
			} else if ([eventName isEqualToString:LAEventNameLockScreenClockDoubleTap]) {
				bounds.size.height = 100.0f;
			} else {
				if (![eventName hasPrefix:@"libactivator.statusbar."] && ![eventName isEqualToString:LAEventNameSlideInFromTopLeft] && ![eventName isEqualToString:LAEventNameSlideInFromTopRight])
					bounds.origin.y += bounds.size.height;
				bounds.size.height = 1.0f;
			}
			[actionSheet showFromRect:bounds inView:view animated:YES];
		} else {
			[actionSheet showInView:view];
			[UIApp setStatusBarOrientation:currentOrientation animated:NO];
		}
		[currentActionSheet release];
		currentActionSheet = actionSheet;
		[currentEvent release];
		currentEvent = [event copy];
		[currentItems release];
		currentItems = compatibleItems;
		[currentListenerName release];
		currentListenerName = [listenerName copy];
		event.handled = YES;
		viewController.allowAllOrientations = NO;
	}
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[currentListenerName release];
	currentListenerName = nil;
	[currentActionSheet dismissWithClickedButtonIndex:currentActionSheet.cancelButtonIndex animated:YES];
	[self performSelector:@selector(cleanup) withObject:nil afterDelay:0.0];
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	[currentListenerName release];
	currentListenerName = nil;
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

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	NSMutableArray *titles = [NSMutableArray array];
	NSDictionary *menuData = [menus objectForKey:listenerName];
	for (NSString *listenerName in [menuData objectForKey:@"items"]) {
		NSString *listenerTitle = [LASharedActivator localizedTitleForListenerName:listenerName];
		if (listenerTitle)
			[titles addObject:listenerTitle];
	}
	return [titles count] ? [titles componentsJoinedByString:@", "] : nil;
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
