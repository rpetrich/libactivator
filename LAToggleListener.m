#import "LAToggleListener.h"
#import "libactivator-private.h"
#import "SimulatorCompat.h"

#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>

#include <notify.h>
#include <dlfcn.h>

@interface NSObject(LAActivator)
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName;
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName;
@end

#define SBSFunction(toggle, name, def, funcType, ...) ({ const void *func = dlsym((toggle), #name); func ? ((funcType)func)(__VA_ARGS__) : (def); })
#define isCapable(toggle) SBSFunction(toggle, isCapable, YES, BOOL (*)(void))
#define isEnabled(toggle) SBSFunction(toggle, isEnabled, NO, BOOL (*)(void))
#define getStateFast(toggle) SBSFunction(toggle, getStateFast, NO, BOOL (*)(void))
#define setState(toggle, newState) SBSFunction(toggle, setState, NO, BOOL (*)(BOOL), newState)
#define getDelayTime(toggle) SBSFunction(toggle, getDelayTime, 0.0f, float (*)(void))
#define allowInCall(toggle) SBSFunction(toggle, allowInCall, NO, BOOL (*)(void))
#define invokeHoldAction(toggle) SBSFunction(toggle, invokeHoldAction, NO, BOOL (*)(void))
#define getStateTryFast(toggle) SBSFunction(toggle, getStateFast, isEnabled(toggle), BOOL (*)(void))

#define ToggleNameFromListenerName(listenerName) ([listenerName substringFromIndex:17])
#define ListenerNameFromToggleName(toggleName) ([@"activatortoggles." stringByAppendingString:toggleName])

static CFMutableDictionaryRef toggles;

@implementation LAToggleListener

static LAToggleListener *sharedInstance;
static UIAlertView *alertView;

+ (void)initialize
{
	CHAutoreleasePoolForScope();
	sharedInstance = [[self alloc] init];
}

+ (id)sharedInstance
{
	return sharedInstance;
}

+ (NSString *)togglesPath
{
	return SCMobilePath(@"/Library/SBSettings/Toggles/");
}

+ (NSString *)defaultThemePath
{
	return SCMobilePath(@"/Library/SBSettings/Themes/Default/");
}

- (id)init
{
	if ((self = [super init])) {
		if (LASharedActivator.runningInsideSpringBoard) {
			toggles = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSString *togglesPath = [LAToggleListener togglesPath];
			for (NSString *subpath in [fileManager contentsOfDirectoryAtPath:togglesPath error:NULL]) {
				if ([subpath hasPrefix:@"."])
					continue;
				if ([subpath isEqualToString:@"Fast Notes"])
					continue;
				if ([subpath isEqualToString:@"Brightness"])
					continue;
				if ([subpath isEqualToString:@"Processes"])
					continue;
				NSString *togglePath = [[togglesPath stringByAppendingPathComponent:subpath] stringByAppendingPathComponent:@"Toggle.dylib"];
				void *toggle = dlopen([togglePath UTF8String], RTLD_LAZY);
				if (toggle && isCapable(toggle)) {
					[LASharedActivator registerListener:self forName:ListenerNameFromToggleName(subpath) ignoreHasSeen:YES];
					CFDictionaryAddValue(toggles, subpath, toggle);
				} else {
					dlclose(toggle);
				}
			}
		}
	}
	return self;
}

- (void)dismiss
{
	[alertView dismissWithClickedButtonIndex:0 animated:YES];
	[alertView release];
	alertView = nil;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	NSString *toggleName = ToggleNameFromListenerName(listenerName);
	return [LASharedActivator localizedStringForKey:[@"LISTENER_TITLE_toggle_" stringByAppendingString:toggleName] value:toggleName];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return [LASharedActivator localizedStringForKey:@"LISTENER_DESCRIPTION_toggle" value:@"Activate/deactivate toggle"];
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return [LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_SBSettings Toggles" value:@"SBSettings Toggles"];
}

- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	NSString *toggleName = ToggleNameFromListenerName(listenerName);
	NSString *defaultThemePath = [LAToggleListener defaultThemePath];
	NSString *path = [[defaultThemePath stringByAppendingPathComponent:toggleName] stringByAppendingPathComponent:@"on.png"];
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (data)
		return data;
	else
		return [NSData dataWithContentsOfFile:[defaultThemePath stringByAppendingPathComponent:@"blankon.png"]];
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	NSData *data = [self activator:activator requiresIconDataForListenerName:listenerName];
	UIImage *image = [UIImage imageWithData:data];
	CGSize size = [image size];
	if (size.width > 29.0f || size.height > 29.0f) {
		CGFloat larger = (size.width > size.height) ? size.width : size.height;
		image = [image _imageScaledToProportion:(29.0f / larger) interpolationQuality:kCGInterpolationDefault];
		return UIImagePNGRepresentation(image);
	} else {
		return data;
	}
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	if (alertView) {
		[alertView dismissWithClickedButtonIndex:0 animated:YES];
		[alertView release];
		alertView = nil;
	} else {
		NSString *toggleName = [self activator:activator requiresLocalizedTitleForListenerName:listenerName];
		void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
		BOOL newState = !isEnabled(toggle);
		setState(toggle, newState);
		notify_post("com.sbsettings.refreshalltoggles");
		alertView = [[UIAlertView alloc] init];
	    alertView.title = [LASharedActivator localizedStringForKey:[@"LISTENER_TITLE_toggle_" stringByAppendingString:toggleName] value:toggleName];
		CGRect frame = alertView.bounds;
		frame.origin.y += frame.size.height - 95.0f;
		frame.size.height = 95.0f;
		UILabel *label = [[UILabel alloc] initWithFrame:frame];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		if (newState)
			label.text = [LASharedActivator localizedStringForKey:@"ENABLED" value:@"Enabled"];
		else
			label.text = [LASharedActivator localizedStringForKey:@"DISABLED" value:@"Disabled"];
		label.backgroundColor = [UIColor clearColor];
		label.textColor = [UIColor whiteColor];
		label.textAlignment = UITextAlignmentCenter;
		[alertView addSubview:label];
		[label release];
		[alertView show];
		[event setHandled:YES];
		[self performSelector:@selector(dismiss) withObject:nil afterDelay:1.5];
	}
}

@end
