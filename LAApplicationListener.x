#import "libactivator.h"
#import "libactivator-private.h"
#import "LAApplicationListener.h"
#import "SpringBoard/AdditionalAPIs.h"

#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

%config(generator=internal);

static LAApplicationListener *sharedApplicationListener;
static NSMutableArray *displayStacks;
static NSArray *allEventModesExceptLockScreen;
static NSArray *ignoredDisplayIdentifiers;

static NSString *systemApplicationsGroupName;
static NSString *userApplicationsGroupName;
static NSString *webClipApplicationsGroupName;

static inline SBDisplayStack *SBWGetDisplayStackAtIndex(NSInteger index)
{
	return index < [displayStacks count] ? [displayStacks objectAtIndex:index] : nil;
}

#define SBWPreActivateDisplayStack        SBWGetDisplayStackAtIndex(0)
#define SBWActiveDisplayStack             SBWGetDisplayStackAtIndex(1)
#define SBWSuspendingDisplayStack         SBWGetDisplayStackAtIndex(2)
#define SBWSuspendedEventOnlyDisplayStack SBWGetDisplayStackAtIndex(3)

#define SBApp(dispId) [(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:dispId]

__attribute__((visibility("hidden")))
@interface LACameraApplicationListener : LAApplicationListener
@end

@implementation LACameraApplicationListener

static LACameraApplicationListener *sharedCameraApplicationListener;

+ (void)initialize
{
	if ((self == [LACameraApplicationListener class])) {
		sharedCameraApplicationListener = [[self alloc] init];
	}
}

+ (id)sharedInstance
{
	return sharedCameraApplicationListener;
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name
{
	SpringBoard *sb = (SpringBoard *)UIApp;
	BOOL canShowLockScreenCameraButton = [sb respondsToSelector:@selector(canShowLockScreenHUDControls)] ? [sb canShowLockScreenHUDControls] : [sb canShowLockScreenCameraButton];
	return canShowLockScreenCameraButton ? activator.availableEventModes : [super activator:activator requiresCompatibleEventModesForListenerWithName:name];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	NSString *eventMode = [activator currentEventMode];
	if (eventMode == LAEventModeLockScreen) {
		SpringBoard *sb = (SpringBoard *)UIApp;
		if ([sb respondsToSelector:@selector(canShowLockScreenHUDControls)] ? [sb canShowLockScreenHUDControls] : [sb canShowLockScreenCameraButton]) {
			SBAwayController *ac = [%c(SBAwayController) sharedAwayController];
			if ([ac cameraIsActive])
				[ac dismissCameraAnimated:YES];
			else {
				if (kCFCoreFoundationVersionNumber >= 690.10)
					[ac _activateCameraAfterCall];
				else
					[ac activateCamera];
				event.handled = YES;
			}
			return;
		}
	}
	[super activator:activator receiveEvent:event forListenerName:listenerName];
}

@end

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
	SBApplication *app = SBApp(listenerName);
	if ([app isSystemApplication]) {
		return ([app respondsToSelector:@selector(webClip)] && [app webClip]) ? webClipApplicationsGroupName : systemApplicationsGroupName;
	} else {
		return userApplicationsGroupName;
	}
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)name
{
	if ([[%c(SBAwayController) sharedAwayController] isPasswordProtected])
		return allEventModesExceptLockScreen;
	else
		return activator.availableEventModes;
}

- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
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
	return image;
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
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
	return image;
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
			[LASharedActivator registerListener:[listenerName isEqualToString:@"com.apple.camera"] ? [LACameraApplicationListener sharedInstance] : sharedApplicationListener forName:listenerName ignoreHasSeen:YES];
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
#ifndef SINGLE
	%init;
#endif
	sharedApplicationListener = [[LAApplicationListener alloc] init];
	systemApplicationsGroupName = [[LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_System Applications" value:@"System Applications"] retain];
	userApplicationsGroupName = [[LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_User Applications" value:@"User Applications"] retain];
	webClipApplicationsGroupName = [[LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_Web Clips" value:@"Web Clips"] retain];
	allEventModesExceptLockScreen = [[NSArray alloc] initWithObjects:LAEventModeSpringBoard, LAEventModeApplication, nil];
	ignoredDisplayIdentifiers = [[NSArray alloc] initWithObjects:@"com.apple.DemoApp", @"com.apple.fieldtest", @"com.apple.springboard", @"com.apple.AdSheet", @"com.apple.iphoneos.iPodOut", @"com.apple.TrustMe", @"com.apple.DataActivation", @"com.apple.WebSheet", @"com.apple.AdSheetPhone", @"com.apple.AdSheetPad", @"com.apple.iosdiagnostics", @"com.apple.purplebuddy", nil];
	displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
}
