#import <Preferences/Preferences.h>
#import <QuartzCore/QuartzCore.h>

#import "libactivator.h"
#import "libactivator-private.h"
#import "ActivatorAdController.h"

// TODO: figure out the proper way to store this in headers
@interface PSViewController (OS32)
@property (nonatomic, retain) PSSpecifier *specifier;
@property (nonatomic, retain) UIView *view;
- (void)viewDidLoad;
@end

@interface UIDevice (OS32)
- (BOOL)isWildcat;
@end

__attribute__((visibility("hidden")))
@interface ActivatorPSViewControllerHost : PSViewController<LASettingsViewControllerDelegate> {
@private
	LASettingsViewController *_settingsController;
	UIView *_wrapperView;
}
- (id)initForContentSize:(CGSize)size;
@property (nonatomic, retain) LASettingsViewController *settingsController;
- (void)loadFromSpecifier:(PSSpecifier *)specifier;
@end

@implementation ActivatorPSViewControllerHost

- (id)initForContentSize:(CGSize)size
{
	if ([PSViewController instancesRespondToSelector:@selector(initForContentSize:)]) {
		if ((self = [super initForContentSize:size])) {
			CGRect frame;
			frame.origin.x = 0.0f;
			frame.origin.y = 0.0f;
			frame.size = size;
			_wrapperView = [[UIView alloc] initWithFrame:frame];
		}
		return self;
	}
	return [super init];
}

- (void)dealloc
{
	_settingsController.delegate = nil;
	[_settingsController release];
	[_wrapperView release];
	[super dealloc];
}

- (LASettingsViewController *)settingsController
{
	return _settingsController;
}

- (void)setSettingsController:(LASettingsViewController *)settingsController
{
	if (_settingsController != settingsController) {
		_settingsController.delegate = nil;
		[_settingsController release];
		_settingsController = [settingsController retain];
		UIView *view = self.view;
		UIView *subview = _settingsController.view;
		subview.frame = view.bounds;
		subview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[view addSubview:subview];
		_settingsController.delegate = self;
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIView *view = self.view;
	UIView *subview = _settingsController.view;
	subview.frame = view.bounds;
	[view addSubview:subview];
}

- (NSString *)navigationTitle
{
	return _settingsController.navigationItem.title;
}

- (UINavigationItem *)navigationItem
{
	return _settingsController.navigationItem;
}

- (void)setSpecifier:(PSSpecifier *)specifier
{
	[self loadFromSpecifier:specifier];
	[super setSpecifier:specifier];
}

- (void)viewWillBecomeVisible:(void *)source
{
	if (source)
		[self loadFromSpecifier:(PSSpecifier *)source];
	UIView *view = self.view;
	UIView *subview = _settingsController.view;
	subview.frame = view.bounds;
	[view addSubview:subview];
	[super viewWillBecomeVisible:source];
}

- (void)viewWillAppear:(BOOL)animated
{
	UIView *view = self.view;
	UIView *subview = _settingsController.view;
	subview.frame = view.bounds;
	[view addSubview:subview];
	[_settingsController viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	[_settingsController viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[_settingsController viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[_settingsController viewDidDisappear:animated];
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier
{
}

- (UIView *)view
{
	return [super view] ?: _wrapperView;
}

- (void)settingsViewController:(LASettingsViewController *)settingsController shouldPushToChildController:(LASettingsViewController *)childController
{
	ActivatorPSViewControllerHost *vch = [[ActivatorPSViewControllerHost alloc] initForContentSize:_settingsController.view.frame.size];
	vch.settingsController = childController;
	[self pushController:vch];
	[vch setParentController:self];
	[vch release];
}

+ (void)enteredBackground
{
	if ([[UIDevice currentDevice] isWildcat])
		return;
	UINavigationController *navigationController = [(id)[UIApplication sharedApplication] rootController];
	while ([navigationController.topViewController isKindOfClass:self]) {
		if ([navigationController.viewControllers count] == 1)
			break;
		[navigationController popViewControllerAnimated:NO];
	}
	[[ActivatorAdController sharedInstance] hideAnimated:NO];
}

+ (void)initialize
{
	[[NSNotificationCenter defaultCenter] addObserver:[ActivatorPSViewControllerHost class] selector:@selector(enteredBackground) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
}

@end

__attribute__((visibility("hidden")))
@interface ActivatorSettingsController : ActivatorPSViewControllerHost<ActivatorAdControllerDelegate> {
@private
	BOOL shouldShowAds;
}
@end

@implementation ActivatorSettingsController

- (void)dealloc
{
	[ActivatorAdController sharedInstance].delegate = nil;
	[super dealloc];
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier
{
	// Load LAListenerSettingsViewController if activatorListener is set in the specifier
	LASettingsViewController *sc;
	NSString *listenerName = [specifier propertyForKey:@"activatorListener"];
	if ([listenerName length]) {
		NSLog(@"libactivator: Configuring %@", listenerName);
		LAListenerSettingsViewController *lsvc = [LAListenerSettingsViewController controller];
		sc = lsvc;
		lsvc.listenerName = listenerName;
		NSString *title = [[specifier propertyForKey:@"activatorTitle"]?:[specifier name] copy];
		if ([title length])
			lsvc.navigationItem.title = title;
		shouldShowAds = NO;
	} else {
		sc = [LARootSettingsController controller];
		shouldShowAds = ![[LASharedActivator _getObjectForPreference:@"LAHideAds"] boolValue];
	}
	self.settingsController = sc;
}

- (void)viewDidBecomeVisible
{
	[super viewDidBecomeVisible];
	if (shouldShowAds) {
		ActivatorAdController *aac = [ActivatorAdController sharedInstance];
		[aac setURL:[LASharedActivator adPaneURL]];
		[aac setDelegate:self];
		[aac display];
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	if (!self.settingsController)
		[self loadFromSpecifier:nil];
	[super viewWillAppear:animated];
	if (shouldShowAds) {
		ActivatorAdController *aac = [ActivatorAdController sharedInstance];
		[aac setURL:[LASharedActivator adPaneURL]];
		[aac setDelegate:self];
		[aac display];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	UIViewController *rootController = [[(UIViewController *)self navigationController].viewControllers objectAtIndex:0];
	UIView *view = rootController.view;
	view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	view = [[view subviews] lastObject];
	view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	if (![(UIViewController *)self navigationController])
		[[ActivatorAdController sharedInstance] hideAnimated:YES];
}

- (BOOL)popControllerWithAnimation:(BOOL)animation
{
	[[ActivatorAdController sharedInstance] hideAnimated:YES];
	return [super popControllerWithAnimation:animation];
}

- (UIView *)activatorAdControllerRequiresTarget:(ActivatorAdController *)ac
{
	return [[self view] superview];
}

@end
