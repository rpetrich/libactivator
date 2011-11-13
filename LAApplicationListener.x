#import "libactivator.h"
#import "libactivator-private.h"
#import "LAApplicationListener.h"

#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

%config(generator=internal);

static LAApplicationListener *sharedApplicationListener;
static NSMutableArray *displayStacks;
static NSArray *allEventModesExceptLockScreen;
static NSArray *ignoredDisplayIdentifiers;

static inline SBDisplayStack *SBWGetDisplayStackAtIndex(NSInteger index)
{
	return index < [displayStacks count] ? [displayStacks objectAtIndex:index] : nil;
}

#define SBWPreActivateDisplayStack        SBWGetDisplayStackAtIndex(0)
#define SBWActiveDisplayStack             SBWGetDisplayStackAtIndex(1)
#define SBWSuspendingDisplayStack         SBWGetDisplayStackAtIndex(2)
#define SBWSuspendedEventOnlyDisplayStack SBWGetDisplayStackAtIndex(3)

#define SBApp(dispId) [(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:dispId]

// TODO: Figure out the proper way to put this in the headers
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_2
@interface SBIcon (OS30)
- (UIImage *)icon;
- (UIImage *)smallIcon;
@end
@interface SBApplication (OS30)
- (NSString *)pathForIcon;
- (NSString *)pathForSmallIcon;
@end
#else
@interface SBIcon (OS32)
- (UIImage *)getIconImage:(NSInteger)sizeIndex;
@end
@interface SBIconModel (OS40)
- (SBIcon *)leafIconForIdentifier:(NSString *)displayIdentifier;
- (NSArray *)leafIcons;
@end
@interface UIImage (OS40)
@property (nonatomic, readonly) CGFloat scale;
@end
@interface SBUIController (OS40)
- (void)activateApplicationAnimated:(SBApplication *)application;
- (void)activateApplicationFromSwitcher:(SBApplication *)application;
@end
#endif

@implementation LAApplicationListener

+ (id)sharedInstance
{
	return sharedApplicationListener;
}

#ifdef DEBUG
- (SBDisplayStack *)displayStackAtIndex:(NSInteger)index
{
	return SBWGetDisplayStackAtIndex(index);
}
#endif

- (BOOL)activateApplication:(SBApplication *)application;
{
	SBApplication *springBoard;
	SBApplicationController *applicationController = (SBApplicationController *)[%c(SBApplicationController) sharedInstance];
	if ([applicationController respondsToSelector:@selector(springBoard)])
		springBoard = [applicationController springBoard];
	else
		springBoard = nil;
	if (!application)
		application = springBoard;
    SBApplication *oldApplication = [self topApplication] ?: springBoard;
    if (oldApplication == application)
    	return NO;
	SBIcon *icon;
    SBIconModel *iconModel = (SBIconModel *)[%c(SBIconModel) sharedInstance];
    if ([iconModel respondsToSelector:@selector(leafIconForIdentifier:)])
		icon = [iconModel leafIconForIdentifier:[application displayIdentifier]];
	else
		icon = [iconModel iconForDisplayIdentifier:[application displayIdentifier]];
	if (icon && [[LAActivator sharedInstance] currentEventMode] == LAEventModeSpringBoard)
		[icon launch];
	else {
		if (oldApplication == springBoard) {
			if ([%c(SBUIController) instancesRespondToSelector:@selector(activateApplicationAnimated:)]) {
				[(SBUIController *)[%c(SBUIController) sharedInstance] activateApplicationAnimated:application];
				return YES;
			}
			[application setDisplaySetting:0x4 flag:YES];
			[SBWPreActivateDisplayStack pushDisplay:application];
		} else if (application == springBoard) {
			[oldApplication setDeactivationSetting:0x2 flag:YES];
			[SBWActiveDisplayStack popDisplay:oldApplication];
			[SBWSuspendingDisplayStack pushDisplay:oldApplication];
		} else {
			if ([%c(SBUIController) instancesRespondToSelector:@selector(activateApplicationFromSwitcher:)]) {
				[(SBUIController *)[%c(SBUIController) sharedInstance] activateApplicationFromSwitcher:application];
				return YES;
			}
			[application setDisplaySetting:0x4 flag:YES];
			[application setActivationSetting:0x40 flag:YES];
			[application setActivationSetting:0x20000 flag:YES];
			[SBWPreActivateDisplayStack pushDisplay:application];
			[oldApplication setDeactivationSetting:0x2 flag:YES];
			[SBWActiveDisplayStack popDisplay:oldApplication];
			[SBWSuspendingDisplayStack pushDisplay:oldApplication];
		}
	}
	return YES;
}

- (SBApplication *)topApplication
{
	return [UIApp respondsToSelector:@selector(_accessibilityFrontMostApplication)] ? [(SpringBoard *)UIApp _accessibilityFrontMostApplication] : [SBWActiveDisplayStack topApplication];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	SBApplication *application = SBApp(listenerName);
	NSString *eventMode = [activator currentEventMode];
	if (eventMode == LAEventModeSpringBoard) {
		[self performSelector:@selector(activateApplication:) withObject:application afterDelay:0.0f];
		[event setHandled:YES];
	} else if (eventMode == LAEventModeLockScreen) {
		SBAwayController *awayController = [%c(SBAwayController) sharedAwayController];
		if (![awayController isPasswordProtected]) {
			[awayController unlockWithSound:NO];
			[self performSelector:@selector(activateApplication:) withObject:application afterDelay:0.0f];
			[event setHandled:YES];
		}
	} else if ([self activateApplication:application]) {
		[event setHandled:YES];
	}
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return [SBApp(listenerName) displayName];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return [activator localizedStringForKey:@"LISTENER_DESCRIPTION_application" value:@"Activate application"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	if ([SBApp(listenerName) isSystemApplication])
		return [activator localizedStringForKey:@"LISTENER_GROUP_TITLE_System Applications" value:@"System Applications"];
	else
		return [activator localizedStringForKey:@"LISTENER_GROUP_TITLE_User Applications" value:@"User Applications"];
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name
{
	if ([[%c(SBAwayController) sharedAwayController] isPasswordProtected])
		return allEventModesExceptLockScreen;
	else
		return activator.availableEventModes;
}

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	SBIcon *icon;
	SBIconModel *iconModel = (SBIconModel *)[%c(SBIconModel) sharedInstance];
	if ([iconModel respondsToSelector:@selector(leafIconForIdentifier:)])
		icon = [iconModel leafIconForIdentifier:listenerName];
	else
		icon = [iconModel iconForDisplayIdentifier:listenerName];
	UIImage *image;
	if ([icon respondsToSelector:@selector(getIconImage:)])
		image = [icon getIconImage:1];
	else
		image = [icon icon];	
	if (image) {
		if ([image respondsToSelector:@selector(scale)])
			*scale = [image scale];
		return UIImagePNGRepresentation(image);
	}
	SBApplication *app = SBApp(listenerName);
	if ([app respondsToSelector:@selector(pathForIcon)])
		return [NSData dataWithContentsOfFile:[app pathForIcon]];
	return nil;
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	CGFloat scale = 1.0f;
	return [self activator:activator requiresIconDataForListenerName:listenerName scale:&scale];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	SBIcon *icon;
	SBIconModel *iconModel = (SBIconModel *)[%c(SBIconModel) sharedInstance];
	if ([iconModel respondsToSelector:@selector(leafIconForIdentifier:)])
		icon = [iconModel leafIconForIdentifier:listenerName];
	else
		icon = [iconModel iconForDisplayIdentifier:listenerName];
	UIImage *image;
	if ([icon respondsToSelector:@selector(getIconImage:)])
		image = [icon getIconImage:0];
	else
		image = [icon smallIcon];	
	if (!image) {
		SBApplication *app = SBApp(listenerName);
		NSData *result;
		if ([app respondsToSelector:@selector(pathForSmallIcon)]) {
			result = [NSData dataWithContentsOfFile:[app pathForSmallIcon]];
			if (result)
				return result;
		}
		image = [icon icon];
		if (!image) {
			if (![app respondsToSelector:@selector(pathForIcon)])
				return nil;
			image = [UIImage imageWithContentsOfFile:[app pathForIcon]];
			if (!image)
				return nil;
		}
	}
	CGSize size = [image size];
	if (size.width > 29.0f || size.height > 29.0f) {
		CGFloat larger = (size.width > size.height) ? size.width : size.height;
		image = [image _imageScaledToProportion:(29.0f / larger) interpolationQuality:kCGInterpolationDefault];
	}
	if ([image respondsToSelector:@selector(scale)])
		*scale = [image scale];
	return UIImagePNGRepresentation(image);
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	CGFloat scale = 1.0f;
	return [self activator:activator requiresSmallIconDataForListenerName:listenerName scale:&scale];
}

@end

%group WithAppController

%hook SBApplication

- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier webClip:(id)webClip path:(NSString *)path bundle:(id)bundle infoDictionary:(NSDictionary *)infoDictionary isSystemApplication:(BOOL)isSystemApplication signerIdentity:(id)signerIdentity provisioningProfileValidated:(BOOL)validated
{
	if ((self = %orig)) {
		NSString *listenerName = [self displayIdentifier];
		if (isSystemApplication) {
			if ([ignoredDisplayIdentifiers containsObject:listenerName]) {
				return self;
			}
			if (![[NSFileManager defaultManager] fileExistsAtPath:[bundle executablePath]]) {
				return self;
			}
		}
		if (![LASharedActivator listenerForName:listenerName])
			[LASharedActivator registerListener:sharedApplicationListener forName:listenerName ignoreHasSeen:YES];
	}
	return self;
}

- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier roleIdentifier:(NSString *)roleIdentifier path:(NSString *)path bundle:(id)bundle infoDictionary:(NSDictionary *)infoDictionary isSystemApplication:(BOOL)isSystemApplication signerIdentity:(id)signerIdentity provisioningProfileValidated:(BOOL)validated
{
	if ((self = %orig)) {
		NSString *listenerName = [self displayIdentifier];
		if (isSystemApplication) {
			if ([ignoredDisplayIdentifiers containsObject:listenerName]) {
				return self;
			}
			if (![[NSFileManager defaultManager] fileExistsAtPath:[bundle executablePath]]) {
				return self;
			}
		}
		if (![LASharedActivator listenerForName:listenerName])
			[LASharedActivator registerListener:sharedApplicationListener forName:listenerName ignoreHasSeen:YES];
	}
	return self;
}

- (void)dealloc
{
	[LASharedActivator unregisterListenerWithName:[self displayIdentifier]];
	%orig;
}

%end

%end

%hook SBDisplayStack

- (id)init
{
	if ((self = %orig)) {
		[displayStacks addObject:self];
	}
	return self;
}

- (void)dealloc
{
	[displayStacks removeObject:self];
	%orig;
}

%end

%hook SBApplicationController

- (id)init
{
	%init(WithAppController);
	return %orig;
}

%end

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (objc_getClass("SBApplicationController")) {
		%init;
		sharedApplicationListener = [[LAApplicationListener alloc] init];
		allEventModesExceptLockScreen = [[NSArray alloc] initWithObjects:LAEventModeSpringBoard, LAEventModeApplication, nil];
		ignoredDisplayIdentifiers = [[NSArray alloc] initWithObjects:@"com.apple.DemoApp", @"com.apple.fieldtest", @"com.apple.springboard", @"com.apple.AdSheet", @"com.apple.iphoneos.iPodOut", @"com.apple.TrustMe", @"com.apple.DataActivation", @"com.apple.WebSheet", @"com.apple.AdSheetPhone", @"com.apple.AdSheetPad", @"com.apple.iosdiagnostics", @"com.apple.purplebuddy", nil];
		displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	[pool drain];
}
