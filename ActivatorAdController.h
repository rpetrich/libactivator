#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ActivatorAdController : NSObject<UIWebViewDelegate> {
@private
	UIWebView *_adView;
	UIView *_target;
	NSURL *_URL;
	BOOL isLoaded;
}

+ (ActivatorAdController *)sharedInstance;
- (void)hideAnimated:(BOOL)animated;
- (void)displayOnTarget:(UIView *)target;

@property (nonatomic, copy) NSURL *URL;

@end
