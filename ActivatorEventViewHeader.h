#import <UIKit/UIKit.h>

@protocol ActivatorEventViewHeaderDelegate;

__attribute__((visibility("hidden")))
@interface ActivatorEventViewHeader : UIView {
@private
	NSString *_listenerName;
	id<ActivatorEventViewHeaderDelegate> _delegate;
}

@property (nonatomic, copy) NSString *listenerName;
@property (nonatomic, assign) id<ActivatorEventViewHeaderDelegate> delegate;

@end

@protocol ActivatorEventViewHeaderDelegate <NSObject>
@required
- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader;
@end
