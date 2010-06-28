#import "LAToggleListener.h"
#import "libactivator-private.h"
#import "SimulatorCompat.h"

#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>
#include <dlfcn.h>

CHDeclareClass(SBAlertItemsController);
CHDeclareClass(SBAlertItem);
CHDeclareClass(ActivatorTogglesAlertItem);

@interface ActivatorMenuAlertItem : SBAlertItem { }
- (id)initWithToggleName:(NSString *)toggleName;
@end

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

CHOptimizedMethod(1, new, id, ActivatorTogglesAlertItem, initWithToggleName, NSString *, toggleName)
{
	if ((self = [self init])) {
		CHIvar(self, _toggleName, NSString *) = [toggleName copy];
	}
	return self;
}

CHOptimizedMethod(0, super, void, ActivatorTogglesAlertItem, dealloc)
{
	[CHIvar(self, _toggleName, NSString *) release];
	CHSuper(0, ActivatorTogglesAlertItem, dealloc);
}

CHOptimizedMethod(2, super, void, ActivatorTogglesAlertItem, configure, BOOL, configure, requirePasscodeForActions, BOOL, require)
{
	NSString *toggleName = CHIvar(self, _toggleName, NSString *);
    UIModalView *alertSheet = [self alertSheet];
    [alertSheet setTitle:toggleName];
	void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
    [alertSheet setBodyText:getStateTryFast(toggle)?@"Enabled":@"Disabled"];
}

@implementation LAToggleListener

static LAToggleListener *sharedInstance;

+ (id)sharedInstance
{
	if (!sharedInstance)
		sharedInstance = [[self alloc] init];
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
		CHLoadLateClass(SBAlertItemsController);
		CHLoadLateClass(SBAlertItem);
		CHRegisterClass(ActivatorTogglesAlertItem, SBAlertItem) {
			CHAddIvar(CHClass(ActivatorTogglesAlertItem), _toggleName, NSString *);
			CHHook(1, ActivatorTogglesAlertItem, initWithToggleName);
			CHHook(0, ActivatorTogglesAlertItem, dealloc);
			CHHook(2, ActivatorTogglesAlertItem, configure, requirePasscodeForActions);
		}
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
			NSString *togglePath = [[togglesPath stringByAppendingPathComponent:subpath] stringByAppendingPathComponent:@"Toggle.dylib"];
			void *toggle = dlopen([togglePath UTF8String], RTLD_LAZY);
			if (toggle && isCapable(toggle)) {
				[LASharedActivator registerListener:self forName:ListenerNameFromToggleName(subpath)];
				CFDictionaryAddValue(toggles, subpath, toggle);
			} else {
				dlclose(toggle);
			}
		}
	}
	return self;
}

- (void)dismiss
{
	[CHSharedInstance(SBAlertItemsController) deactivateAlertItemsOfClass:CHClass(ActivatorTogglesAlertItem)];
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
		size.width = 29.0f;
		size.height = 29.0f;
		image = [image _imageScaledToSize:size interpolationQuality:kCGInterpolationDefault];
		return UIImagePNGRepresentation(image);
	} else {
		return data;
	}
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	SBAlertItemsController *aic = CHSharedInstance(SBAlertItemsController);
	if ([aic isShowingAlertOfClass:CHClass(ActivatorTogglesAlertItem)])
		[aic deactivateAlertItemsOfClass:CHClass(ActivatorTogglesAlertItem)];
	else {
		NSString *toggleName = [self activator:activator requiresLocalizedTitleForListenerName:listenerName];
		void *toggle = (void *)CFDictionaryGetValue(toggles, toggleName);
		setState(toggle, !isEnabled(toggle));
		ActivatorTogglesAlertItem *atai = [CHAlloc(ActivatorTogglesAlertItem) initWithToggleName:toggleName];
		[aic activateAlertItem:atai];
		[atai release];
		[event setHandled:YES];
		[self performSelector:@selector(dismiss) withObject:nil afterDelay:1.5f];
	}
}

@end
