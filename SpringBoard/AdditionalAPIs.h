#import <SpringBoard/SpringBoard.h>

@interface SpringBoard (iOS40)
- (void)resetIdleTimerAndUndim;
@end

@interface SpringBoard (iOS50)
- (NSArray *)appsRegisteredForVolumeEvents;
- (BOOL)isCameraApp;
- (BOOL)canShowLockScreenCameraButton;
- (void)activateAssistantWithOptions:(id)options withCompletion:(id)completionBlock;
@end

@interface SpringBoard (iOS51)
- (BOOL)canShowLockScreenHUDControls;
@end

@interface SBAwayController (iOS40)
- (void)_unlockWithSound:(BOOL)sound isAutoUnlock:(BOOL)unlock;
@end

@interface SBAwayController (iOS50)
- (BOOL)cameraIsActive;
- (void)activateCamera;
- (void)dismissCameraAnimated:(BOOL)animated;
- (void)toggleCameraButton;
- (void)_activateCameraAfterCall;
@end

@interface SBAlert (iOS50)
- (BOOL)handleVolumeUpButtonPressed;
- (BOOL)handleVolumeDownButtonPressed;
@end

@interface VolumeControl (iOS40)
+ (float)volumeStep;
- (void)_changeVolumeBy:(float)volumeAdjust;
- (void)hideVolumeHUDIfVisible;
@end

@interface SBUIController (iOS40)
- (BOOL)isSwitcherShowing;
- (void)activateApplicationAnimated:(SBApplication *)application;
- (void)activateApplicationFromSwitcher:(SBApplication *)application;
- (BOOL)activateSwitcher;
- (void)dismissSwitcher;
- (void)_toggleSwitcher;
@end

@interface SBUIController (iOS50)
- (void)lockFromSource:(int)source;
- (void)dismissSwitcherAnimated:(BOOL)animated;
@end

@interface SBIconController (iOS40)
- (id)currentFolderIconList;
@property (nonatomic, readonly) SBSearchController *searchController;
- (void)closeFolderAnimated:(BOOL)animated;
@end

@interface SBAppSwitcherController : NSObject
- (NSDictionary *)_currentIcons;
@end

@interface SBIcon (OS30)
- (UIImage *)icon;
- (UIImage *)smallIcon;
@end

@interface SBIcon (OS32)
- (UIImage *)getIconImage:(NSInteger)sizeIndex;
@end

@interface SBApplication (OS30)
- (NSString *)pathForIcon;
- (NSString *)pathForSmallIcon;
- (id)webClip;
@end

@interface SBIconModel (iOS40)
- (SBIcon *)leafIconForIdentifier:(NSString *)displayIdentifier;
- (NSArray *)leafIcons;
@end

@interface UIImage (iOS40)
@property (nonatomic, readonly) CGFloat scale;
@end

@interface SBMediaController (iOS4)
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

@interface SBAssistantController : NSObject
+ (BOOL)deviceSupported;
+ (BOOL)preferenceEnabled;
+ (BOOL)shouldEnterAssistant;
+ (SBAssistantController *)sharedInstance;
@property (nonatomic, readonly, getter=isAssistantVisible) BOOL assistantVisible;
- (void)dismissAssistant;
@end

@interface SBBulletinListController : NSObject
+ (SBBulletinListController *)sharedInstance;
- (void)showListViewAnimated:(BOOL)animated;
- (void)hideListViewAnimated:(BOOL)animated;
- (BOOL)listViewIsActive;
- (void)handleShowNotificationsGestureBeganWithTouchLocation:(CGPoint)touchLocation;
- (void)handleShowNotificationsGestureChangedWithTouchLocation:(CGPoint)touchLocation velocity:(CGPoint)velocity;
- (void)handleShowNotificationsGestureEndedWithVelocity:(CGPoint)velocity completion:(void (^)())completion;
- (void)handleShowNotificationsGestureCanceled;
@end
