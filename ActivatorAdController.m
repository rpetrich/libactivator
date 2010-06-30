#import "ActivatorAdController.h"
#import <UIKit/UIKit2.h>

static ActivatorAdController *sharedAdController;

// This entire class is a big giant hack; I wish I could use the real AdMob SDK :(

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
	[_adView setDelegate:nil];
	[_adView release];
	[_URL release];
	[super dealloc];
}

@synthesize URL = _URL;

- (void)hideAnimationDidFinish
{
	[_adView removeFromSuperview];
}

- (void)hideAnimated:(BOOL)animated
{
	if (_target && [_adView superview] == [_target superview]) {
		if (animated) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDidStopSelector:@selector(hideAnimationDidFinish)];
			CGRect targetFrame = [_target frame];
			CGRect adFrame = [_adView frame];
			targetFrame.size.height += adFrame.size.height;
			[_target setFrame:targetFrame];
			adFrame.origin.y += adFrame.size.height;
			[_adView setFrame:adFrame];
			[UIView commitAnimations];
		} else {
			CGRect targetFrame = [_target frame];
			targetFrame.size.height += [_adView frame].size.height;
			[_adView removeFromSuperview];
		}
	} else {
		[_adView removeFromSuperview];
	}
	[_target release];
	_target = nil;
}

- (void)tryShowAnimated
{
	if (!_target)
		return;
	if ([_adView superview])
		return;
	CGFloat height = [[_adView stringByEvaluatingJavaScriptFromString:@"document.getElementById('adFrame').clientHeight"] floatValue];
	if (height <= 0.0f) {
		[self performSelector:@selector(tryShowAnimated) withObject:nil afterDelay:0.1f];
		return;
	}
	// Set initial position
	CGRect targetFrame = [_target frame];
	CGRect adFrame = targetFrame;
	adFrame.origin.y += targetFrame.size.height;
	adFrame.size.height = height;
	[_adView setFrame:adFrame];
	[[_target superview] addSubview:_adView];
	// Update Scroller
	[_adView stringByEvaluatingJavaScriptFromString:@"var s=document.getElementById('adFrame').style;s.position='absolute';s.top='0';"];
	[[_adView _scroller] setScrollingEnabled:NO];
	// Slide from bottom animation
	targetFrame.size.height -= adFrame.size.height;
	adFrame.origin.y -= adFrame.size.height;
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5f];
	[_target setFrame:targetFrame];
	[_adView setFrame:adFrame];
	[UIView commitAnimations];
}

- (void)displayOnTarget:(UIView *)target
{
	[self hideAnimated:NO];
	_target = [target retain];
	if (isLoaded)
		[self tryShowAnimated];
	else {
		[_adView setDelegate:self];
		[_adView loadRequest:[NSURLRequest requestWithURL:_URL]];
	}
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
	isLoaded = YES;
	[self performSelector:@selector(tryShowAnimated) withObject:nil afterDelay:0.33f];
}

@end
