#import "Settings.h"
#import "libactivator-private.h"
#import <objc/runtime.h>

#ifndef __IPHONE_5_0
@interface UIWebView (iOS5)
@property (nonatomic, readonly) UIScrollView *scrollView;
@end
#endif

__attribute__((visibility("hidden")))
@interface ActivatorAdView : UIView <UIWebViewDelegate> {
	UINavigationController *navigationController;
	UIWebView *webView;
	NSURL *URL;
	NSInteger visibleCount;
	BOOL loaded;
	BOOL pendingLoad;
	UINavigationController *expansionController;
}

+ (ActivatorAdView *)adViewForNavigationController:(UINavigationController *)navigationController;

@property (nonatomic, retain) UINavigationController *navigationController;

- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;

- (CGSize)sizeForAd;

@end

__attribute__((visibility("hidden")))
@interface ActivatorAdExpandedViewController : UIViewController {
@private
	NSURLRequest *request;
	UIWebView *webView;
}
@end

@implementation ActivatorAdExpandedViewController

- (id)initWithRequest:(NSURLRequest *)_request
{
	if ((self = [super init])) {
		request = [_request copy];
	}
	return self;
}

- (void)dealloc
{
	[webView stopLoading];
	[webView release];
	[request release];
	[super dealloc];
}

- (void)loadView
{
	if (!webView) {
		webView = [[UIWebView alloc] initWithFrame:CGRectZero];
		[webView loadRequest:request];
	}
	self.view = webView;
}

- (void)viewDidUnload
{
	[webView stopLoading];
	[webView release];
	webView = nil;
	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end

__attribute__((visibility("hidden")))
@interface ActivatorAdToolbar : UIToolbar
@end

@implementation ActivatorAdToolbar

- (CGSize)sizeThatFits:(CGSize)size
{
	size = [super sizeThatFits:size];
	ActivatorAdView *adView = [self.layer valueForKey:[ActivatorAdView description]];
	if (adView)
		size.height = [adView sizeForAd].height;
	return size;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	ActivatorAdView *adView = [self.layer valueForKey:[ActivatorAdView description]];
	adView.frame = self.bounds;
}

@end

@implementation ActivatorAdView

+ (ActivatorAdView *)adViewForNavigationController:(UINavigationController *)navigationController
{
	if (!navigationController)
		return nil;
	UIToolbar *toolbar = navigationController.toolbar;
	CALayer *layer = toolbar.layer;
	NSString *key = [self description];
	ActivatorAdView *result = [layer valueForKey:key];
	if (!result) {
		if ([toolbar isMemberOfClass:[UIToolbar class]])
			object_setClass(toolbar, [ActivatorAdToolbar class]);
		result = [[[ActivatorAdView alloc] initWithFrame:toolbar.bounds] autorelease];
		result.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		result.navigationController = navigationController;
		[layer setValue:result forKey:key];
	}
	return result;
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissAdExpansionQuickly) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
		CGRect webViewFrame;
		webViewFrame.origin.x = 0.0f;
		webViewFrame.origin.y = 0.0f;
		webViewFrame.size = [self sizeForAd];
		webView = [[UIWebView alloc] initWithFrame:webViewFrame];
		webView.backgroundColor = [UIColor clearColor];
		webView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:webView];
		webView.delegate = self;
		URL = [[[LAActivator sharedInstance] adPaneURL] retain];
		// Update Scroller
		if ([webView respondsToSelector:@selector(scrollView)])
			[[webView scrollView] setScrollEnabled:NO];
		else if ([webView respondsToSelector:@selector(_scrollView)])
			[[webView _scrollView] setScrollEnabled:NO];
		else if ([webView respondsToSelector:@selector(_scroller)])
			[[webView _scroller] setScrollingEnabled:NO];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	webView.delegate = nil;
	[webView release];
	[expansionController release];
	[navigationController release];
	[URL release];
	[super dealloc];
}

@synthesize navigationController;

- (void)addToToolbar
{
	UIToolbar *toolbar = navigationController.toolbar;
	CGRect frame = toolbar.bounds;
	self.frame = frame;
	CGSize size = [self sizeForAd];
	frame.origin.x = (long)(frame.size.width - size.width) / 2;
	frame.origin.y = (long)(frame.size.height - size.height) / 2;
	frame.size = size;
	webView.frame = frame;
	[toolbar addSubview:self];
	self.alpha = 1.0f;
}

- (void)showAnimated:(BOOL)animated
{
	visibleCount++;
	if (visibleCount) {
		if (loaded) {
			[self addToToolbar];
			[navigationController setToolbarHidden:NO animated:animated];
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
			[self performSelector:@selector(reload) withObject:nil afterDelay:30.0];
		} else {
			pendingLoad = YES;
			if (visibleCount == 1)
				[webView loadRequest:[NSURLRequest requestWithURL:URL]];
		}
	}
}

- (void)hideAnimated:(BOOL)animated
{
	visibleCount--;
	if (!visibleCount) {
		pendingLoad = NO;
		UIView *view = navigationController.topViewController.view;
		CGRect bounds = view.bounds;
		for (UIView *viewToFix in view.subviews)
			if (CGRectEqualToRect(viewToFix.frame, bounds))
				viewToFix.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[navigationController setToolbarHidden:YES animated:animated];
		if (animated) {
			[UIView beginAnimations:nil context:NULL];
			self.alpha = 0.0f;
			[UIView setAnimationDuration:1.0];
			[UIView commitAnimations];
		} else {
			self.alpha = 0.0f;
		}
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
	}
}

- (CGSize)sizeForAd
{
	CGSize result;
	result.width = [[webView stringByEvaluatingJavaScriptFromString:@"window.getAdWidth()"] floatValue] ?: 320.0f;
	result.height = [[webView stringByEvaluatingJavaScriptFromString:@"window.getAdHeight()"] floatValue] ?: 50.0f; 
	return result;
}

- (void)reload
{
	[webView reload];
}

- (void)didFinishLoad
{
	loaded = YES;
	if (pendingLoad) {
		pendingLoad = NO;
		[self addToToolbar];
		[navigationController setToolbarHidden:NO animated:YES];
	} else {
		CGSize size = [self sizeForAd];
		CGRect frame = self.bounds;
		frame.origin.x = (long)(frame.size.width - size.width) / 2;
		frame.origin.y = (long)(frame.size.height - size.height) / 2;
		frame.size = size;
		webView.frame = frame;
	}
	if ([navigationController respondsToSelector:@selector(_updateBarsForCurrentInterfaceOrientation)])
		[navigationController _updateBarsForCurrentInterfaceOrientation];
	[self performSelector:@selector(reload) withObject:nil afterDelay:30.0];
}

- (void)dismissAdExpansion
{
	if (expansionController) {
		[navigationController dismissModalViewControllerAnimated:YES];
		[expansionController release];
		expansionController = nil;
	}
}

- (void)dismissAdExpansionQuickly
{
	if (expansionController) {
		[navigationController dismissModalViewControllerAnimated:NO];
		[expansionController release];
		expansionController = nil;
	}
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	if ([[[url absoluteString] lowercaseString] isEqualToString:@"about:blank"])
		return NO;
	if ([url isEqual:URL])
		return YES;
	if ([url.scheme hasPrefix:@"http"]) {
		if (!expansionController) {
			UIViewController *vc = [[ActivatorAdExpandedViewController alloc] initWithRequest:request];
			expansionController = [[UINavigationController alloc] initWithRootViewController:vc];
			UINavigationItem *ni = vc.navigationItem;
			ni.title = Localize(LASharedActivator.bundle, @"Advertisement", @"Advertisement");
			UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissAdExpansion)];
			ni.rightBarButtonItem = bbi;
			[bbi release];
			[vc release];
			if ([expansionController respondsToSelector:@selector(setModalPresentationStyle:)])
				[expansionController setModalPresentationStyle:UIModalPresentationPageSheet];
			[navigationController presentModalViewController:expansionController animated:YES];
		}
	} else {
		[[UIApplication sharedApplication] openURL:url];
	}
	return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self performSelector:@selector(didFinishLoad) withObject:nil afterDelay:0.5];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[self performSelector:@selector(reload) withObject:nil afterDelay:30.0];
}

@end

@implementation LASettingsViewController (API)

static BOOL shouldShowAds;

+ (void)updateAdSettings
{
	shouldShowAds = ![[LASharedActivator _getObjectForPreference:@"LAHideAds"] boolValue];
}

+ (void)initialize
{
	[self updateAdSettings];
}

+ (id)controller
{
	return [[[self alloc] init] autorelease];
}

- (id)init
{
	return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc
{
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	[_savedNavigationController release];
	[super dealloc];
}

- (UITableView *)tableView
{
	return _tableView;
}

- (id<LASettingsViewControllerDelegate>)delegate
{
	return _delegate;
}

- (void)setDelegate:(id<LASettingsViewControllerDelegate>)delegate
{
	_delegate = delegate;
}

- (BOOL)showsAd
{
	return shouldShowAds;
}

- (void)loadView
{
	if (!_tableView) {
		/*NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(didEnterBackground) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
		[nc addObserver:self selector:@selector(willEnterForeground) name:@"UIApplicationWillEnterForegroundNotification" object:nil];*/
		_tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		_tableView.rowHeight = 55.0f;
		_tableView.delegate = self;
		_tableView.dataSource = self;
	}
	self.view = _tableView;
}

static inline UINavigationController *FindNavigationController(UIViewController *viewController)
{
	if (![UIViewController respondsToSelector:@selector(viewControllerForView:)])
		return viewController.navigationController;
	do {
		UINavigationController *navigationController = viewController.navigationController;
		if (navigationController)
			return navigationController;
		if (![viewController isViewLoaded])
			return nil;
	} while ((viewController = [UIViewController viewControllerForView:viewController.view.superview]));
	return nil;
}

- (void)viewDidUnload
{
	if (_savedNavigationController) {
		[[ActivatorAdView adViewForNavigationController:_savedNavigationController] hideAnimated:NO];
		[_savedNavigationController release];
		_savedNavigationController = nil;
	}
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	_tableView = nil;
	[super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if ([self showsAd] && !_savedNavigationController) {
		_savedNavigationController = [FindNavigationController(self) retain];
		[[ActivatorAdView adViewForNavigationController:_savedNavigationController] showAnimated:animated];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if ([self showsAd] && !_savedNavigationController) {
		_savedNavigationController = [FindNavigationController(self) retain];
		[[ActivatorAdView adViewForNavigationController:_savedNavigationController] showAnimated:animated];
	}
}

- (void)viewDidDisappear:(BOOL)animated
{
	if (_savedNavigationController) {
		[[ActivatorAdView adViewForNavigationController:_savedNavigationController] hideAnimated:animated];
		[_savedNavigationController release];
		_savedNavigationController = nil;
	}
	[super viewDidDisappear:animated];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushSettingsController:(LASettingsViewController *)controller
{
	if (_delegate) {
		controller.delegate = _delegate;
		[_delegate settingsViewController:self shouldPushToChildController:controller];
	} else {
		[self.navigationController pushViewController:controller animated:YES];
	}
}

- (void)didReceiveMemoryWarning
{
	// Do Nothing!
}

- (void)purgeMemoryForReason:(int)reason
{
	// Do Nothing
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait)
		|| ([UIDevice instancesRespondToSelector:@selector(userInterfaceIdiom)] && ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad));
}

@end
