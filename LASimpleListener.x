#import "libactivator.h"
#import "libactivator-private.h"
#import "LASimpleListener.h"
#import "LAApplicationListener.h"
#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBGestureRecognizer.h>
#import <GraphicsServices/GraphicsServices.h>
#import <CaptainHook/CaptainHook.h>
#import <MediaPlayer/MediaPlayer.h>

%config(generator=internal);

static LASimpleListener *sharedSimpleListener;

@interface SBIconController (OS40)
@property (nonatomic, readonly) SBSearchController *searchController;
- (void)closeFolderAnimated:(BOOL)animated;
@end

@interface SBUIController (OS40Switcher)
- (BOOL)isSwitcherShowing;
- (BOOL)activateSwitcher;
- (void)dismissSwitcher;
- (void)_toggleSwitcher;
@end

@interface SBUIController (iOS50)
- (void)lockFromSource:(int)source;
- (void)dismissSwitcherAnimated:(BOOL)animated;
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
- (void)_postData;
@end

@interface SBAlertItemsController (iOS42)
- (BOOL)hasAlertOfClass:(Class)alertClass;
@end

@interface TWTweetComposeViewController : UIViewController
@property (nonatomic, copy) id completionHandler;
@end

@interface UIViewController (iOS5)
@property (nonatomic, readwrite, assign) UIInterfaceOrientation interfaceOrientation;
@end

@interface SpringBoard (iOS5)
- (void)activateAssistantWithOptions:(id)options withCompletion:(id)completionBlock;
@end

@interface SBAssistantController : NSObject
+ (BOOL)deviceSupported;
+ (BOOL)preferenceEnabled;
+ (BOOL)shouldEnterAssistant;
@end

void UIKeyboardEnableAutomaticAppearance();
void UIKeyboardDisableAutomaticAppearance();

__attribute__((visibility("hidden")))
@interface ActivatorEmptyViewController : UIViewController
// So empty inside…
@end

@implementation ActivatorEmptyViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown)
		|| ([UIDevice instancesRespondToSelector:@selector(userInterfaceIdiom)] && ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad));
}

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
	[(SpringBoard *)UIApp relaunchSpringBoard];
	return YES;
}

/* // A safeMode method isn't needed; it should safe mode anyway :P
- (void)safeMode
{
	[(SpringBoard *)UIApp enterSafeMode];
}*/

- (BOOL)reboot
{
	[(SpringBoard *)UIApp reboot];
	return YES;
}

- (BOOL)powerDown
{
	[(SpringBoard *)UIApp powerDown];
	return YES;
}

- (BOOL)spotlight
{
	[[LAApplicationListener sharedInstance] activateApplication:nil];
	SBIconController *iconController = (SBIconController *)[%c(SBIconController) sharedInstance];
	[iconController scrollToIconListAtIndex:-1 animate:NO];
	if ([iconController respondsToSelector:@selector(closeFolderAnimated:)])
		[iconController closeFolderAnimated:YES];
	SBSearchController *searchController;
	if ([%c(SBSearchController) respondsToSelector:@selector(sharedInstance)])
		searchController = (SBSearchController *)[%c(SBSearchController) sharedInstance];
	else
		searchController = [(SBIconController *)[%c(SBIconController) sharedInstance] searchController];
	[[searchController searchView] setShowsKeyboard:YES animated:YES];
	return YES;
}

- (BOOL)takeScreenshot
{
	SBScreenShotter *screenShotter = (SBScreenShotter *)[%c(SBScreenShotter) sharedInstance];
	if (screenShotter.writingScreenshot)
		return NO;
	[screenShotter saveScreenshot:YES];
	return YES;
}

- (BOOL)voiceControl
{
	SBVoiceControlAlert *alert = [%c(SBVoiceControlAlert) pendingOrActiveAlert];
	if (alert) {
		[alert cancel];
		return YES;
	}
	if ([%c(SBVoiceControlAlert) shouldEnterVoiceControl]) {
		alert = [[%c(SBVoiceControlAlert) alloc] initFromMenuButton];
		[alert _workspaceActivate];
		[alert release];
		return YES;
	}
	return NO;
}

- (BOOL)activateVirtualAssistant
{
	if ([%c(SBAssistantController) preferenceEnabled]) {
		if ([%c(SBAssistantController) shouldEnterAssistant]) {
			[(SpringBoard *)UIApp activateAssistantWithOptions:nil withCompletion:nil];
			return YES;
		}
	}
	return NO;
}

- (BOOL)activateSwitcher
{
	SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
	if ([sharedController isSwitcherShowing]) {
		if ([sharedController respondsToSelector:@selector(dismissSwitcherAnimated:)])
			[sharedController dismissSwitcherAnimated:YES];
		else
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

- (BOOL)showNowPlayingBar
{
	SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
	if (![sharedController isSwitcherShowing]) {
		[sharedController _toggleSwitcher];
		// Repeatedly attempt to Activate switcher
		// Apple bug--will not activate if taps are active
		[self performSelector:@selector(showNowPlayingBar) withObject:nil afterDelay:0.0];
	} else {
		UIScrollView *scrollView = CHIvar(CHIvar((SBAppSwitcherController *)[%c(SBAppSwitcherController) sharedInstance], _bottomBar, id), _scrollView, UIScrollView *);
		CGPoint contentOffset = scrollView.contentOffset;
		CGFloat desiredOffset = (kCFCoreFoundationVersionNumber <= kCFCoreFoundationVersionNumber_iOS_4_2) ? 0.0f : scrollView.bounds.size.width;
		if (contentOffset.x == desiredOffset) {
			if ([sharedController respondsToSelector:@selector(dismissSwitcherAnimated:)])
				[sharedController dismissSwitcherAnimated:YES];
			else
				[sharedController dismissSwitcher];
			return NO;
		} else {
			contentOffset.x = desiredOffset;
			[scrollView setContentOffset:contentOffset animated:NO];
		}
	}
	return YES;
}

- (BOOL)showVolumeBar
{
	SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
	if (![sharedController isSwitcherShowing]) {
		[sharedController _toggleSwitcher];
		// Repeatedly attempt to Activate switcher
		// Apple bug--will not activate if taps are active
		[self performSelector:@selector(showVolumeBar) withObject:nil afterDelay:0.0];
	} else {
		UIScrollView *scrollView = CHIvar(CHIvar((SBAppSwitcherController *)[%c(SBAppSwitcherController) sharedInstance], _bottomBar, id), _scrollView, UIScrollView *);
		CGPoint contentOffset = scrollView.contentOffset;
		if (contentOffset.x == 0.0f) {
			if ([sharedController respondsToSelector:@selector(dismissSwitcherAnimated:)])
				[sharedController dismissSwitcherAnimated:YES];
			else
				[sharedController dismissSwitcher];
			return NO;
		} else {
			contentOffset.x = 0.0f;
			[scrollView setContentOffset:contentOffset animated:NO];
		}
	}
	return YES;
}

- (BOOL)showLockScreen
{
	SBUIController *controller = (SBUIController *)[%c(SBUIController) sharedInstance];
	if ([controller respondsToSelector:@selector(lock)])
		[controller lock];
	if ([controller respondsToSelector:@selector(lockFromSource:)])
		[controller lockFromSource:0];
	[controller wakeUp:nil];
	return YES;
}

- (BOOL)doNothing
{
	return YES;
}

- (void)fixStatusBarTime
{
	[[%c(SBStatusBarDataManager) sharedDataManager] enableLock:NO time:YES];
}

- (BOOL)dismissLockScreen
{
	[[%c(SBAwayController) sharedAwayController] unlockWithSound:objc_msgSend(%c(SBSoundPreferences), @selector(playLockSound)) != nil];
	if (%c(SBStatusBarController))
		[[%c(SBStatusBarController) sharedStatusBarController] setIsLockVisible:NO isTimeVisible:YES];
	else if (%c(SBStatusBarDataManager)) {
		[[%c(SBStatusBarDataManager) sharedDataManager] enableLock:NO time:YES];
		[self performSelector:@selector(fixStatusBarTime) withObject:nil afterDelay:0.3];
	}
	return YES;
}

- (BOOL)toggleLockScreen
{
	return [[%c(SBAwayController) sharedAwayController] isLocked]
		? [self dismissLockScreen]
		: [self showLockScreen];
}

- (BOOL)togglePlayback
{
	[(SBMediaController *)[%c(SBMediaController) sharedInstance] togglePlayPause];
	return YES;
}

- (BOOL)previousTrack
{
	[(SBMediaController *)[%c(SBMediaController) sharedInstance] changeTrack:-1];
	return YES;
}

- (BOOL)nextTrack
{
	[(SBMediaController *)[%c(SBMediaController) sharedInstance] changeTrack:1];
	return YES;
}

- (BOOL)musicControls
{
	SBAlertItemsController *controller = (SBAlertItemsController *)[%c(SBAlertItemsController) sharedInstance];
	if ([controller respondsToSelector:@selector(hasAlertOfClass:)]) {
		if ([controller hasAlertOfClass:%c(SBNowPlayingAlertItem)]) {
			[controller deactivateAlertItemsOfClass:%c(SBNowPlayingAlertItem)];
			return NO;
		}
	} else if ([controller isShowingAlertOfClass:%c(SBNowPlayingAlertItem)]) {
		[controller deactivateAlertItemsOfClass:%c(SBNowPlayingAlertItem)];
		return NO;
	}
	if ([%c(SBAwayController) instancesRespondToSelector:@selector(toggleMediaControls)]) {
		SBAwayController *ac = [%c(SBAwayController) sharedAwayController];
		if ([ac isLocked])
			return [ac toggleMediaControls];
	}
	SBMediaController *mc = (SBMediaController *)[%c(SBMediaController) sharedInstance];
	if ([mc respondsToSelector:@selector(mediaControlsDestinationApp)] && ![mc mediaControlsDestinationApp]) {
		SBApplication *application = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:@"com.apple.mobileipod"];
		return [[LAApplicationListener sharedInstance] activateApplication:application];
	}
	SBNowPlayingAlertItem *newAlert = [[%c(SBNowPlayingAlertItem) alloc] init];
	if (newAlert) {
		shouldAddNowPlayingButton = NO;
		[controller activateAlertItem:newAlert];
		[newAlert release];
		return YES;
	} else {
		return [self showNowPlayingBar];
	}
}

- (BOOL)showPhoneFavorites
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:@"doubletap://com.apple.mobilephone?view=FAVORITES"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneRecents
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=RECENTS" : @"mobilephone-recents"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneContacts
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:@"doubletap://com.apple.mobilephone?view=CONTACTS"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneKeypad
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:@"doubletap://com.apple.mobilephone?view=KEYPAD"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneVoicemail
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=VOICEMAIL" : @"vmshow:"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)firstSpringBoardPage
{
	SBIconController *ic = (SBIconController *)[%c(SBIconController) sharedInstance];
	SBUIController *uic = (SBUIController *)[%c(SBUIController) sharedInstance];
	BOOL result = NO;
	if ([uic respondsToSelector:@selector(isSwitcherShowing)] && [uic isSwitcherShowing]) {
		if ([uic respondsToSelector:@selector(dismissSwitcherAnimated:)])
			[uic dismissSwitcherAnimated:YES];
		else
			[uic dismissSwitcher];
		result = YES;
	}
	if ([[LAApplicationListener sharedInstance] topApplication]) {
		if ([ic respondsToSelector:@selector(closeFolderAnimated:)])
			[ic closeFolderAnimated:NO];
		[ic scrollToIconListAtIndex:0 animate:NO];
		static BOOL inside;
		if (!inside) {
			inside = YES;
			[uic clickedMenuButton];
			inside = NO;
		}
		[ic scrollToIconListAtIndex:0 animate:NO];
		return YES;
	}
	if ([ic isEditing]) {
		[ic setIsEditing:NO];
		result = YES;
	}
	if ([ic respondsToSelector:@selector(closeFolderAnimated:)]) {
		[ic closeFolderAnimated:YES];
		result = YES;
	}
	if ([ic currentIconListIndex]) {
		[ic scrollToIconListAtIndex:0 animate:YES];
		result = YES;
	}
	return result;
}

- (BOOL)activateNotificationCenter
{
	SBBulletinListController *blc = (SBBulletinListController *)[%c(SBBulletinListController) sharedInstance];
	if (blc) {
		if (![blc listViewIsActive]) {
			[blc showListViewAnimated:YES];
			return YES;
		}
		[blc hideListViewAnimated:YES];
	}
	return NO;
}

static TWTweetComposeViewController *tweetComposer;
static UIWindow *tweetWindow;
static UIWindow *tweetFormerKeyWindow;

- (void)hideTweetWindow
{
	tweetWindow.hidden = YES;
	[tweetWindow release];
	tweetWindow = nil;
}

- (BOOL)composeTweet
{
	if (tweetComposer) {
		[tweetWindow.firstResponder resignFirstResponder];
		[tweetFormerKeyWindow makeKeyWindow];
		[tweetFormerKeyWindow release];
		tweetFormerKeyWindow = nil;
		[self performSelector:@selector(hideTweetWindow) withObject:nil afterDelay:0.5];
		[tweetWindow.rootViewController dismissModalViewControllerAnimated:YES];
		[tweetComposer release];
		tweetComposer = nil;
	} else {
		tweetComposer = [[%c(TWTweetComposeViewController) alloc] init];
		if (!tweetComposer)
			return NO;
		if (tweetWindow)
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTweetWindow) object:nil];
		else
			tweetWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
		tweetWindow.windowLevel = UIWindowLevelStatusBar;
		[tweetFormerKeyWindow release];
		tweetFormerKeyWindow = [[UIWindow keyWindow] retain];
		UIViewController *vc = [[ActivatorEmptyViewController alloc] init];
		vc.interfaceOrientation = [(SpringBoard *)UIApp activeInterfaceOrientation];
		tweetWindow.rootViewController = vc;
		tweetComposer.completionHandler = ^(int result) {
			[tweetWindow.firstResponder resignFirstResponder];
			[tweetFormerKeyWindow makeKeyWindow];
			[tweetFormerKeyWindow release];
			tweetFormerKeyWindow = nil;
			[self performSelector:@selector(hideTweetWindow) withObject:nil afterDelay:0.5];
			[vc dismissModalViewControllerAnimated:YES];
			[tweetComposer release];
			tweetComposer = nil;
		};
		[tweetWindow makeKeyAndVisible];
		[vc presentModalViewController:tweetComposer animated:YES];
		[vc release];
	}
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

%hook TWSession

- (void)showTwitterSettingsIfNeeded
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:@"prefs:root=TWITTER"]];
}

%end

+ (void)initialize
{
	if (self == [LASimpleListener class]) {
#ifndef SINGLE
		%init;
#endif
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
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.nothing"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.first-springboard-page"];
		if ([%c(SBVoiceControlAlert) shouldEnterVoiceControl])
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.voice-control"];
		if ([%c(SBAssistantController) deviceSupported])
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.virtual-assistant"];
		if (GSSystemHasCapability(CFSTR("multitasking"))) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.activate-switcher"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.show-now-playing-bar"];
			if ((kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_4_2) && !GSSystemHasCapability(CFSTR("ipad"))) {
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.audio.show-volume-bar"];
			}
		}
		if (%c(SBBulletinListController)) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.activate-notification-center"];
		}
		// Twitter
		if (%c(TWTweetComposeViewController)) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.twitter.compose-tweet"];
		}
		// Lock Screen
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.dismiss"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.show"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.lockscreen.toggle"];
		// iPod
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.toggle-playback"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.previous-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.next-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.music-controls"];
		// Phone
		if (GSSystemHasCapability(CFSTR("telephony"))) {
			if (kCFCoreFoundationVersionNumber < 675.0) {
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.favorites"];
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.contacts"];
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.keypad"];
			}
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.recents"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.voicemail"];
		}
	}
}

@end 