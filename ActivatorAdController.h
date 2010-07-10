#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol ActivatorAdControllerDelegate;

__attribute__((visibility("hidden")))
@interface ActivatorAdController : NSObject<UIWebViewDelegate> {
@private
	UIWebView *_adView;
	NSURL *_URL;
	BOOL isLoaded;
	UIView *_target;
	id<ActivatorAdControllerDelegate> _delegate;
}

+ (ActivatorAdController *)sharedInstance;
- (void)hideAnimated:(BOOL)animated;
- (void)display;

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, assign) id<ActivatorAdControllerDelegate> delegate;

@end

@protocol ActivatorAdControllerDelegate<NSObject>
- (UIView *)activatorAdControllerRequiresTarget:(ActivatorAdController *)ac;
@end
