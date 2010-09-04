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
CHDeclareClass(SBStatusBarDataManager);
CHDeclareClass(SBMediaController);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBSoundPreferences);

static LASimpleListener *sharedSimpleListener;

@interface SBIconController (OS40)
@property (nonatomic, readonly) SBSearchController *searchController;
@end

@interface SBUIController (OS40Switcher)
- (BOOL)isSwitcherShowing;
- (BOOL)activateSwitcher;
- (void)dismissSwitcher;
- (void)_toggleSwitcher;
@end

@interface SBMediaController (OS4)
- (id)mediaControlsDestinationApp;
@end

@interface SBStatusBarDataManager : NSObject {
	struct {
		BOOL itemIsEnabled[20];
		BOOL timeString[64];
		int gsmSignalStrengthRaw;
		int gsmSignalStrengthBars;
		BOOL serviceString[100];
		BOOL serviceImageBlack[100];
		BOOL serviceImageSilver[100];
		BOOL operatorDirectory[1024];
		unsigned serviceContentType;
		int wifiSignalStrengthRaw;
		int wifiSignalStrengthBars;
		unsigned dataNetworkType;
		int batteryCapacity;
		unsigned batteryState;
		int bluetoothBatteryCapacity;
		int thermalColor;
		unsigned slowActivity : 1;
		BOOL activityDisplayId[256];
		unsigned bluetoothConnected : 1;
		unsigned displayRawGSMSignal : 1;
		unsigned displayRawWifiSignal : 1;
	} _data;
	int _actions;
	BOOL _itemIsEnabled[20];
	BOOL _itemIsCloaked[20];
	int _updateBlockDepth;
	BOOL _dataChangedSinceLastPost;
	NSDateFormatter *_timeItemDateFormatter;
	NSTimer *_timeItemTimer;
	NSString *_timeItemTimeString;
	BOOL _cellRadio;
	BOOL _registered;
	BOOL _simError;
	BOOL _simulateInCallStatusBar;
	NSString *_serviceString;
	NSString *_serviceImageBlack;
	NSString *_serviceImageSilver;
	NSString *_operatorDirectory;
	BOOL _showsActivityIndicatorOnHomeScreen;
	int _thermalColor;
}
+ (SBStatusBarDataManager *)sharedDataManager;
- (void)enableLock:(BOOL)showLock time:(BOOL)showTime;
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
	if ([CHClass(SBVoiceControlAlert) shouldEnterVoiceControl]) {
		SBVoiceControlAlert *alert = [CHAlloc(SBVoiceControlAlert) init];
		[alert activate];
		[alert release];
		return YES;
	}
	return NO;
}

- (BOOL)activateSwitcher
{
	SBUIController *sharedController = CHSharedInstance(SBUIController);
	if ([sharedController isSwitcherShowing]) {
		[sharedController dismissSwitcher];
		return NO;
	}
	[sharedController _toggleSwitcher];
	// Repeatedly attempt to Activate switcher
	// Apple bug--will not activate if taps are active
	if (![sharedController isSwitcherShowing])
		[self performSelector:@selector(activateSwitcher) withObject:nil afterDelay:0.05f];
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
	[[CHClass(SBAwayController) sharedAwayController] unlockWithSound:objc_msgSend(CHClass(SBSoundPreferences), @selector(playLockSound)) != nil];
	if (CHClass(SBStatusBarController))
		[[CHClass(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
	else if (CHClass(SBStatusBarDataManager))
		[[CHClass(SBStatusBarDataManager) sharedDataManager] enableLock:NO time:YES];
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
	SBMediaController *mc = CHSharedInstance(SBMediaController);
	if ([mc respondsToSelector:@selector(mediaControlsDestinationApp)] && ![mc mediaControlsDestinationApp]) {
		SBApplication *application = [CHSharedInstance(SBApplicationController) applicationWithDisplayIdentifier:@"com.apple.mobileipod"];
		return [[LAApplicationListener sharedInstance] activateApplication:application];
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
		if ([CHClass(SBVoiceControlAlert) shouldEnterVoiceControl])
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.voice-control"];
		if (GSSystemHasCapability(CFSTR("multitasking")))
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.activate-switcher"];
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
		CHLoadLateClass(SBStatusBarDataManager);
		CHLoadLateClass(SBMediaController);
		CHLoadLateClass(SBApplicationController);
		CHLoadLateClass(SBSoundPreferences);
	}
}

@end 