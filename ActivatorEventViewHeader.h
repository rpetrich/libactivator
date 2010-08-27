#import <UIKit/UIKit.h>

@protocol ActivatorEventViewHeaderDelegate;

__attribute__((visibility("hidden")))
@interface ActivatorEventViewHeader : UIView {
@private
	NSSet *_listenerNames;
	id<ActivatorEventViewHeaderDelegate> _delegate;
}

@property (nonatomic, copy) NSSet *listenerNames;
@property (nonatomic, assign) id<ActivatorEventViewHeaderDelegate> delegate;

@end

@protocol ActivatorEventViewHeaderDelegate <NSObject>
@required
- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader;
@end
