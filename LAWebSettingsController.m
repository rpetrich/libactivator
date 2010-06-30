// Workaround to allow everything
// TODO: find a way to avoid defining this
#import <Availability.h>
#undef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(_mac, _iphone)

#import "libactivator-private.h"

@interface UIWebView (OS32)
@property (nonatomic, readonly) UIScrollView *_scrollView;
@end

@implementation LAWebSettingsController

- (void)hideShadows
{
	if ([_webView respondsToSelector:@selector(_scroller)]) {
		id scroller = [_webView _scroller];
		if ([scroller respondsToSelector:@selector(setShowBackgroundShadow:)])
			[scroller setShowBackgroundShadow:NO];
	}
	if ([_webView respondsToSelector:@selector(_scrollView)]) {
		UIScrollView *scrollView = [_webView _scrollView];
		if ([scrollView respondsToSelector:@selector(_setShowsBackgroundShadow:)])
			[scrollView _setShowsBackgroundShadow:NO];
	}
}

- (id)init
{
	if ((self = [super init])) {
		_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
		[_webView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
		[_webView setDelegate:self];
		_activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[_activityView startAnimating];
		_activityView.center = CGPointZero;
		[_activityView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
		[_webView addSubview:_activityView];
		[self hideShadows];
	}
	return self;
}

- (void)loadView
{
	self.view = _webView;
}

- (void)dealloc
{
	[_webView setDelegate:nil];
	[_webView stopLoading];
	[_webView release];
	[_activityView stopAnimating];
	[_activityView release];
	[super dealloc];
}

- (void)loadURL:(NSURL *)url
{
	[self hideShadows];
	[_webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	[self hideShadows];
	NSURL *url = [request URL];
	NSString *urlString = [url absoluteString];
	if ([urlString isEqualToString:@"about:Blank"])
		return YES;
	if ([urlString hasPrefix:@"http://rpetri.ch/"])
		return YES;
	[[UIApplication sharedApplication] openURL:url];
	return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self hideShadows];
	[_activityView stopAnimating];
	[_activityView setHidden:YES];
}

@end
