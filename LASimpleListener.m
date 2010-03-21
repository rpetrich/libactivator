#import "libactivator.h"
#import "libactivator-private.h"
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

static LASimpleListener *sharedSimpleListener;

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
	[[CHSharedInstance(SBSearchController) searchView] setShowsKeyboard:YES animated:YES];
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
	MPMusicPlayerController *iPod = [MPMusicPlayerController iPodMusicPlayer];
	switch ([iPod playbackState]) {
		case MPMusicPlaybackStateStopped:
		case MPMusicPlaybackStatePaused:
		case MPMusicPlaybackStateInterrupted:
			[iPod play];
			break;
		default:
			[iPod pause];
			break;
	}
	return YES;
}

- (BOOL)previousTrack
{
	[[MPMusicPlayerController iPodMusicPlayer] skipToPreviousItem];
	return YES;
}

- (BOOL)nextTrack
{
	MPMusicPlayerController *iPod = [MPMusicPlayerController iPodMusicPlayer];
	switch ([iPod playbackState]) {
		case MPMusicPlaybackStateStopped:
		case MPMusicPlaybackStatePaused:
		case MPMusicPlaybackStateInterrupted:
			[iPod play];
			break;
		default:
			[iPod skipToNextItem];
			break;
	}
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

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	NSString *listenerName = [activator assignedListenerNameForEvent:event];
	NSString *selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
	if (objc_msgSend(self, NSSelectorFromString(selector), activator, event))
		[event setHandled:YES];
}

+ (LASimpleListener *)sharedInstance
{
	return sharedSimpleListener;
}

+ (void)load
{
	if (!sharedSimpleListener) {
		CHAutoreleasePoolForScope();
		LAActivator *activator = [LAActivator sharedInstance];
		sharedSimpleListener = [[self alloc] init];
		// System
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.homebutton"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.sleepbutton"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.respring"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.safemode"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.reboot"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.powerdown"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.spotlight"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.take-screenshot"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.system.voice-control"];
		// Lock Screen
		[activator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.dismiss"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.show"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.toggle"];
		// iPod
		[activator registerListener:sharedSimpleListener forName:@"libactivator.ipod.toggle-playback"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.ipod.previous-track"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.ipod.next-track"];
		[activator registerListener:sharedSimpleListener forName:@"libactivator.ipod.music-controls"];
		CHLoadLateClass(SBIconController);
		CHLoadLateClass(SBSearchController);
		CHLoadLateClass(SBAlertItemsController);
		CHLoadLateClass(SBNowPlayingAlertItem);
		CHLoadLateClass(SBScreenShotter);
		CHLoadLateClass(SBVoiceControlAlert);
		CHLoadLateClass(SBAwayController);
		CHLoadLateClass(SBUIController);
	}
}

@end 