#import "LAMenuListenerSelectionController.h"
#import "LAListenerTableViewDataSource.h"
#import "libactivator-private.h"

@interface LAMenuListenerSelectionController () <LAListenerTableViewDataSourceDelegate>
@end

@implementation LAMenuListenerSelectionController

@synthesize disallowedListenerNames;

- (id)init
{
	if ((self = [super init])) {
		_dataSource = [[LAListenerTableViewDataSource alloc] init];
	}
	return self;
}

- (void)dealloc
{
	_dataSource.delegate = nil;
	[_dataSource release];
	[_selectedListenerName release];
	[disallowedListenerNames release];
	[super dealloc];
}

@synthesize selectedListenerName = _selectedListenerName;

- (void)loadView
{
	[super loadView];
	_dataSource.delegate = nil;
	_dataSource.delegate = self;
	self.tableView.dataSource = _dataSource;
}

- (BOOL)dataSource:(LAListenerTableViewDataSource *)dataSource shouldAllowListenerWithName:(NSString *)listenerName
{
	return ![disallowedListenerNames containsObject:listenerName];
}

- (void)dataSource:(LAListenerTableViewDataSource *)dataSource appliedContentToCell:(UITableViewCell *)cell forListenerWithName:(NSString *)listenerName
{
	BOOL assigned = [listenerName isEqualToString:_selectedListenerName];
	cell.accessoryType = assigned ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	NSString *listenerName = [_dataSource listenerNameForRowAtIndexPath:indexPath];
	if (![listenerName isEqualToString:_selectedListenerName]) {
		for (UITableViewCell *cell in [tableView visibleCells])
			cell.accessoryType = UITableViewCellAccessoryNone;
		[tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
		[self willChangeValueForKey:@"selectedListenerName"];
		[_selectedListenerName release];
		_selectedListenerName = [listenerName copy];
		[self didChangeValueForKey:@"selectedListenerName"];
	}
}


@end
