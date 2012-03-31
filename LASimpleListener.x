#import "libactivator.h"
#import "libactivator-private.h"
#import "LASimpleListener.h"
#import "LAApplicationListener.h"
#import "SpringBoard/AdditionalAPIs.h"
#import "SlideEvents.h"

#import <UIKit/UIKit2.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBGestureRecognizer.h>
#import <GraphicsServices/GraphicsServices.h>
#import <CaptainHook/CaptainHook.h>
#import <MediaPlayer/MediaPlayer.h>

%config(generator=internal);

static LASimpleListener *sharedSimpleListener;

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
			SBAssistantController *assistant = (SBAssistantController *)[%c(SBAssistantController) sharedInstance];
			if (assistant.assistantVisible)
				[assistant dismissAssistant];
			else {
				[(SpringBoard *)UIApp activateAssistantWithOptions:nil withCompletion:nil];
				return YES;
			}
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

- (void)showNowPlayingBarInternal
{
	SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
	if (![sharedController isSwitcherShowing]) {
		[sharedController _toggleSwitcher];
		// Repeatedly attempt to Activate switcher
		// Apple bug--will not activate if taps are active
		[self performSelector:@selector(showNowPlayingBarInternal) withObject:nil afterDelay:0.0];
	} else {
		UIScrollView *scrollView = CHIvar(CHIvar((SBAppSwitcherController *)[%c(SBAppSwitcherController) sharedInstance], _bottomBar, id), _scrollView, UIScrollView *);
		CGPoint contentOffset = scrollView.contentOffset;
		contentOffset.x = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 0.0f : scrollView.bounds.size.width;
		[scrollView setContentOffset:contentOffset animated:NO];
	}
}

- (BOOL)showNowPlayingBar
{
	SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
	if (![sharedController isSwitcherShowing]) {
		[sharedController _toggleSwitcher];
		// Repeatedly attempt to Activate switcher
		// Apple bug--will not activate if taps are active
		[self performSelector:@selector(showNowPlayingBarInternal) withObject:nil afterDelay:0.0];
		return YES;
	} else {
		UIScrollView *scrollView = CHIvar(CHIvar((SBAppSwitcherController *)[%c(SBAppSwitcherController) sharedInstance], _bottomBar, id), _scrollView, UIScrollView *);
		CGFloat switcherWidth = scrollView.bounds.size.width;
		if (!scrollView || (switcherWidth <= 0.0f)) {
			[self performSelector:@selector(showNowPlayingBarInternal) withObject:nil afterDelay:0.0];
			return YES;
		}
		CGFloat scrollOffset = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 0.0f : switcherWidth;
		CGPoint contentOffset = scrollView.contentOffset;
		if (contentOffset.x == scrollOffset) {
			SBUIController *sharedController = (SBUIController *)[%c(SBUIController) sharedInstance];
			if ([sharedController respondsToSelector:@selector(dismissSwitcherAnimated:)])
				[sharedController dismissSwitcherAnimated:YES];
			else
				[sharedController dismissSwitcher];
			return NO;
		} else {
			contentOffset.x = scrollOffset;
			[scrollView setContentOffset:contentOffset animated:NO];
			return YES;
		}
	}
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

- (BOOL)playMedia
{
	SBMediaController *mc = (SBMediaController *)[%c(SBMediaController) sharedInstance];
	if (![mc isPlaying]) {
		[mc togglePlayPause];
		return YES;
	}
	return NO;
}

- (BOOL)pauseMedia
{
	SBMediaController *mc = (SBMediaController *)[%c(SBMediaController) sharedInstance];
	if ([mc isPlaying]) {
		[mc togglePlayPause];
		return YES;
	}
	return NO;
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
		if ([ac isLocked] && [ac respondsToSelector:@selector(toggleCameraButton)]) {
			SpringBoard *sb = (SpringBoard *)UIApp;
			if ([sb respondsToSelector:@selector(canShowLockScreenCameraButton)]) {
				if ([sb canShowLockScreenCameraButton])
					[ac toggleCameraButton];
			} else if ([sb respondsToSelector:@selector(canShowLockScreenHUDControls)]) {
				if ([sb canShowLockScreenHUDControls])
					[ac toggleCameraButton];
			}
			return [ac toggleMediaControls];
		}
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
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=FAVORITES" : @"mobilephone-recents:favorites"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneRecents
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=RECENTS" : @"mobilephone-recents:"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneContacts
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=CONTACTS" : @"mobilephone-recents:contacts"] publicURLsOnly:NO];
	return YES;
}

- (BOOL)showPhoneKeypad
{
	[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:(kCFCoreFoundationVersionNumber < 675.0) ? @"doubletap://com.apple.mobilephone?view=KEYPAD" : @"mobilephone-recents:keypad"] publicURLsOnly:NO];
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
	SBBulletinListController *blc = (SBBulletinListController *)[%c(SBBulletinListController) sharedInstance];
	if ([blc listViewIsActive]) {
		[blc hideListViewAnimated:YES];
		result = YES;
	}
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
			if ([uic respondsToSelector:@selector(_handleButtonEventToSuspendDisplays:displayWasSuspendedOut:)])
				[uic _handleButtonEventToSuspendDisplays:YES displayWasSuspendedOut:NULL];
			else {
				[uic clickedMenuButton];
				[ic scrollToIconListAtIndex:0 animate:NO];
			}
			inside = NO;
		}
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

- (BOOL)openURLWithActivator:(LAActivator *)activator event:(LAEvent *)event listenerName:(NSString *)listenerName
{
	NSString *url = [activator infoDictionaryValueOfKey:@"url" forListenerWithName:listenerName];
	if (url) {
		[(SpringBoard *)UIApp applicationOpenURL:[NSURL URLWithString:url] publicURLsOnly:NO];
		return YES;
	}
	return NO;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	NSString *selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
	if (objc_msgSend(self, NSSelectorFromString(selector), activator, event, listenerName))
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
		if ([%c(SBAssistantController) deviceSupported]) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.system.virtual-assistant"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.virtual-assistant"];
		}
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
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.pause-playback"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.resume-playback"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.previous-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.next-track"];
		[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.ipod.music-controls"];
		// Phone
		bool hasTelephony = GSSystemHasCapability(CFSTR("telephony"));
		if (hasTelephony) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.favorites"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.contacts"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.keypad"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.recents"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.phone.voicemail"];
		}
		if (kCFCoreFoundationVersionNumber >= 675.0) {
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.about"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.accessibility"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.auto-lock"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.bluetooth"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.brightness"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.date-time"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.equalizer"];
			if (GSSystemHasCapability(CFSTR("venice")))
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.facetime"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.general"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.icloud"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.international"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.keyboard"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.location-services"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.music"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.network"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.notes"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.notifications"];
			if (hasTelephony)
				[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.phone"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.photos"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.safari"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.sounds"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.store"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.twitter"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.usage"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.vpn"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.wallpaper"];
			[LASharedActivator registerListener:sharedSimpleListener forName:@"libactivator.settings.wifi"];
		}
	}
}

@end 