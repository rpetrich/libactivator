#import <UIKit/UIKit.h>

@protocol LAListenerTableViewDataSourceDelegate;

__attribute__((visibility("hidden")))
@interface LAListenerTableViewDataSource : NSObject<UITableViewDataSource> {
@private
	id<LAListenerTableViewDataSourceDelegate> _delegate;
	NSMutableDictionary *_listeners;
	NSArray *_groups;
}

@property (nonatomic, assign) id<LAListenerTableViewDataSourceDelegate> delegate;

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

@protocol LAListenerTableViewDataSourceDelegate <NSObject>
- (BOOL)dataSource:(LAListenerTableViewDataSource *)dataSource shouldAllowListenerWithName:(NSString *)listenerName;
- (void)dataSource:(LAListenerTableViewDataSource *)dataSource appliedContentToCell:(UITableViewCell *)cell forListenerWithName:(NSString *)listenerName;
@end
