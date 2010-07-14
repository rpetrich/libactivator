#import "ActivatorAdController.h"
#import <UIKit/UIKit2.h>

static ActivatorAdController *sharedAdController;

// This entire class is a big giant hack; I wish I could use the real AdMob SDK :(

@interface UIWebView (OS32)
- (id)_scrollView;
@end

@interface UIDevice (OS32)
- (BOOL)isWildcat;
@end

@implementation ActivatorAdController

+ (void)initialize
{
	sharedAdController = [[self alloc] init];
}

+ (ActivatorAdController *)sharedInstance
{
	return sharedAdController;
}

- (id)init
{
	if ((self = [super init])) {
		_adView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	}
	return self;
}

- (void)dealloc
{
	[_target release];
	_adView.delegate = nil;
	[_adView release];
	[_URL release];
	[super dealloc];
}

@synthesize URL = _URL, delegate = _delegate;

- (void)hideAnimationDidFinish
{
	[_adView removeFromSuperview];
}

- (void)hideAnimated:(BOOL)animated
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(display) object:nil];
	CGRect adFrame = _adView.frame;
	CGRect targetFrame = _target.frame;
	targetFrame.size.height += adFrame.size.height;
	if (animated && _target) {
		adFrame.origin.y += adFrame.size.height;
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.5f];
		[UIView setAnimationDidStopSelector:@selector(hideAnimationDidFinish)];
		_target.frame = targetFrame;
		_adView.frame = adFrame;
		[UIView commitAnimations];
	} else {
		_target.frame = targetFrame;
		[_adView removeFromSuperview];
	}
	[_target release];
	_target = nil;
}

- (void)display
{
	if ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat])
		return;
	if (!isLoaded) {
		_adView.delegate = self;
		[_adView loadRequest:[NSURLRequest requestWithURL:_URL]];
	} else {
		if (_target)
			return;
		CGFloat height = [[_adView stringByEvaluatingJavaScriptFromString:@"document.getElementById('adFrame').clientHeight"] floatValue];
		if (height <= 0.0f) {
			height = [[_adView stringByEvaluatingJavaScriptFromString:@"document.getElementById('aframe0').clientHeight"] floatValue];
			if (height <= 0.0f) {
				[self performSelector:@selector(display) withObject:nil afterDelay:0.5];
				return;
			}
		}
		UIView *target = [_delegate activatorAdControllerRequiresTarget:self];
		if (!target) {
			[self performSelector:@selector(display) withObject:nil afterDelay:0.5];
			return;
		}
		_target = [target retain];
		// Set initial position
		CGRect targetFrame = [_target frame];
		CGRect adFrame = targetFrame;
		adFrame.origin.y += targetFrame.size.height;
		adFrame.size.height = height;
		_adView.frame = adFrame;
		[[_target superview] addSubview:_adView];
		// Slide from bottom animation
		targetFrame.size.height -= adFrame.size.height;
		adFrame.origin.y -= adFrame.size.height;
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.5f];
		_target.frame = targetFrame;
		_adView.frame = adFrame;
		[UIView commitAnimations];
	}
}

- (void)becomeLoaded
{
	isLoaded = YES;
	[self display];
	[self performSelector:@selector(reload) withObject:nil afterDelay:30.0f];
	// Update Scroller
	if ([_adView respondsToSelector:@selector(_scrollView)])
		[[_adView _scrollView] setScrollEnabled:NO];
	if ([_adView respondsToSelector:@selector(_scroller)])
		[[_adView _scroller] setScrollingEnabled:NO];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	if ([[url absoluteString] isEqualToString:@"about:Blank"])
		return NO;
	if ([url isEqual:_URL])
		return YES;
	[[UIApplication sharedApplication] openURL:url];
	return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self performSelector:@selector(becomeLoaded) withObject:nil afterDelay:1.0f];
}

- (void)reload
{
	[_adView reload];
}

@end
