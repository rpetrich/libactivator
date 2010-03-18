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

__attribute__((visibility("hidden")))
@interface LASystemActivator : NSObject<LAListener> {
}
+ (LASystemActivator *)sharedInstance;
@end

static LASystemActivator *sharedSystemActivator;

@implementation LASystemActivator

- (void)homeButton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventMenuButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventMenuButtonUp;
	GSSendSystemEvent(&record);	
}

- (void)sleepButton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventLockButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventLockButtonUp;
	GSSendSystemEvent(&record);	
}

- (void)respring
{
	[(SpringBoard *)[UIApplication sharedApplication] relaunchSpringBoard];
}

/* // A safeMode method isn't needed; it should safe mode anyway :P
- (void)safeMode
{
	[(SpringBoard *)[UIApplication sharedApplication] enterSafeMode];
}*/

- (void)reboot
{
	[(SpringBoard *)[UIApplication sharedApplication] reboot];
}

- (void)powerDown
{
	[(SpringBoard *)[UIApplication sharedApplication] powerDown];
}

- (void)spotlight
{
	[[LAActivator sharedInstance] _activateApplication:nil];
	[CHSharedInstance(SBIconController) scrollToIconListAtIndex:-1 animate:NO];
	[[CHSharedInstance(SBSearchController) searchView] setShowsKeyboard:YES animated:YES];	
}

- (void)togglePlayback
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
}

- (void)previousTrack
{
	[[MPMusicPlayerController iPodMusicPlayer] skipToPreviousItem];
}

- (void)nextTrack
{
	[[MPMusicPlayerController iPodMusicPlayer] skipToNextItem];
}

- (void)musicControls
{
	SBAlertItemsController *controller = CHSharedInstance(SBAlertItemsController);
	if ([controller isShowingAlertOfClass:CHClass(SBNowPlayingAlertItem)])
		[controller deactivateAlertItemsOfClass:CHClass(SBNowPlayingAlertItem)];
	else {
		shouldAddNowPlayingButton = NO;
		SBNowPlayingAlertItem *newAlert = [CHAlloc(SBNowPlayingAlertItem) init];
		[controller activateAlertItem:newAlert];
		[newAlert release];
	}
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	NSString *listenerName = [activator assignedListenerNameForEvent:event];
	NSString *selector = [activator infoDictionaryValueOfKey:@"selector" forListenerWithName:listenerName];
	objc_msgSend(self, NSSelectorFromString(selector));
	[event setHandled:YES];
}

#define RegisterAction(name) \
	[activator registerListener:shared forName:name]

+ (LASystemActivator *)sharedInstance
{
	return sharedSystemActivator;
}

+ (void)load
{
	CHAutoreleasePoolForScope();
	LAActivator *activator = [LAActivator sharedInstance];
	sharedSystemActivator = [[self alloc] init];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.homebutton"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.sleepbutton"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.respring"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.safemode"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.reboot"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.powerdown"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.system.spotlight"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.ipod.toggle-playback"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.ipod.previous-track"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.ipod.next-track"];
	[activator registerListener:sharedSystemActivator forName:@"libactivator.ipod.music-controls"];
	CHLoadLateClass(SBIconController);
	CHLoadLateClass(SBSearchController);
	CHLoadLateClass(SBAlertItemsController);
	CHLoadLateClass(SBNowPlayingAlertItem);
}

@end 