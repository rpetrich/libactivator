#import "libactivator.h"
#import "libactivator-private.h"
#import "LAApplicationListener.h"
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <GraphicsServices/GraphicsServices.h>
#import <CaptainHook/CaptainHook.h>
#import <MediaPlayer/MediaPlayer.h>

CHDeclareClass(SBIconController);
CHDeclareClass(SBSearchController);
CHDeclareClass(SBAlertItemsController);
CHDeclareClass(SBNowPlayingAlertItem);
CHDeclareClass(SBScreenShotter);
CHDeclareClass(SBVoiceControlAlert);
CHDeclareClass(SBAwayController);
CHDeclareClass(SBUIController);
CHDeclareClass(SBStatusBarController);
CHDeclareClass(SBMediaController);

static LASimpleListener *sharedSimpleListener;

@interface SBIconController (OS40)
@property (nonatomic, readonly) SBSearchController *searchController;
@end

@implementation LASimpleListener

- (BOOL)homeButton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventMenuButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventMenuButtonUp;
	GSSendSystemEvent(&record);
	return YES;
}

- (BOOL)sleepButton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventLockButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventLockButtonUp;
	GSSendSystemEvent(&record);
	return YES;
}

- (BOOL)respring
{
	[(SpringBoard *)[UIApplication sharedApplication] relaunchSpringBoard];
	return YES;
}

/* // A safeMode method isn't needed; it should safe mode anyway :P
- (void)safeMode
{
	[(SpringBoard *)[UIApplication sharedApplication] enterSafeMode];
}*/

- (BOOL)reboot
{
	[(SpringBoard *)[UIApplication sharedApplication] reboot];
	return YES;
}

- (BOOL)powerDown
{
	[(SpringBoard *)[UIApplication sharedApplication] powerDown];
	return YES;
}

- (BOOL)spotlight
{
	[[LAApplicationListener sharedInstance] activateApplication:nil];
	[CHSharedInstance(SBIconController) scrollToIconListAtIndex:-1 animate:NO];
	SBSearchController *searchController;
	if ([CHClass(SBSearchController) respondsToSelector:@selector(sharedInstance)])
		searchController = CHSharedInstance(SBSearchController);
	else
		searchController = [CHSharedInstance(SBIconController) searchController];
	[[searchController searchView] setShowsKeyboard:YES animated:YES];
	return YES;
}

- (BOOL)takeScreenshot
{
	SBScreenShotter *screenShotter = CHSharedInstance(SBScreenShotter);
	if (screenShotter.writingScreenshot)
		return NO;
	[screenShotter saveScreenshot:YES];
	return YES;
}

- (BOOL)voiceControl
{
	SBVoiceControlAlert *alert = [CHAlloc(SBVoiceControlAlert) init];
	[alert activate];
	[alert release];
	return YES;
}

- (BOOL)showLockScreen
{
	SBUIController *controller = CHSharedInstance(SBUIController);
	[controller lock];
	[controller wakeUp:nil];
	return YES;
}

- (BOOL)dismissLockScreen
{
	[[CHClass(SBAwayController) sharedAwayController] unlockWithSound:YES];
	[[CHClass(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
	return YES;
}

- (BOOL)toggleLockScreen
{
	return [[CHClass(SBAwayController) sharedAwayController] isLocked]
		? [self dismissLockScreen]
		: [self showLockScreen];
}

- (BOOL)togglePlayback
{
	[CHSharedInstance(SBMediaController) togglePlayPause];
	return YES;
}

- (BOOL)previousTrack
{
	[CHSharedInstance(SBMediaController) changeTrack:-1];
	return YES;
}

- (BOOL)nextTrack
{
	[CHSharedInstance(SBMediaController) changeTrack:1];
	return YES;
}

- (BOOL)musicControls
{
	SBAlertItemsController *controller = CHSharedInstance(SBAlertItemsController);
	if ([controller isShowingAlertOfClass:CHClass(SBNowPlayingAlertItem)]) {
		[controller deactivateAlertItemsOfClass:CHClass(SBNowPlayingAlertItem)];
		return NO;
	}
	shouldAddNowPlayingButton = NO;
	SBNowPlayingAlertItem *newAlert = [CHAlloc(SBNowPlayingAlertItem) init];
	[controller activateAlertItem:newAlert];
	[newAlert release];
	return YES;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	NSString *selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
	if (objc_msgSend(self, NSSelectorFromString(selector), activator, event))
		[event setHandled:YES];
}

+ (LASimpleListener *)sharedInstance
{
	return sharedSimpleListener;
}

+ (void)initialize
{
	if (!sharedSimpleListener) {
		CHAutoreleasePoolForScope();
		sharedSimpleListener = [[self alloc] init];
		// System
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.homebutton"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.sleepbutton"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.respring"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.safemode"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.reboot"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.powerdown"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.spotlight"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.take-screenshot"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.voice-control"];
		// Lock Screen
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.dismiss"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.show"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.toggle"];
		// iPod
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.toggle-playback"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.previous-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.next-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.music-controls"];
		CHLoadLateClass(SBIconController);
		CHLoadLateClass(SBSearchController);
		CHLoadLateClass(SBAlertItemsController);
		CHLoadLateClass(SBNowPlayingAlertItem);
		CHLoadLateClass(SBScreenShotter);
		CHLoadLateClass(SBVoiceControlAlert);
		CHLoadLateClass(SBAwayController);
		CHLoadLateClass(SBUIController);
		CHLoadLateClass(SBStatusBarController);
		CHLoadLateClass(SBMediaController);
	}
}

@end 