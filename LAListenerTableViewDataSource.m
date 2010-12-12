#import "LAListenerTableViewDataSource.h"
#import "libactivator-private.h"

@implementation LAListenerTableViewDataSource

- (void)dealloc
{
	[_listeners release];
	[_groups release];
	[super dealloc];
}

- (id<LAListenerTableViewDataSourceDelegate>)delegate
{
	return _delegate;
}

- (void)setDelegate:(id<LAListenerTableViewDataSourceDelegate>)delegate
{
	_delegate = delegate;
	[_listeners release];
	_listeners = [[LASharedActivator _cachedAndSortedListeners] mutableCopy];
	for (NSString *key in [_listeners allKeys]) {
		NSArray *group = [_listeners objectForKey:key];
		NSMutableArray *mutableGroup = [NSMutableArray array];
		BOOL hasItems = NO;
		for (NSString *listenerName in group) {
			if ([delegate dataSource:self shouldAllowListenerWithName:listenerName]) {
				[mutableGroup addObject:listenerName];
				hasItems = YES;
			}
		}
		if (hasItems)
			[_listeners setObject:mutableGroup forKey:key];
		else
			[_listeners removeObjectForKey:key];
	}
	[_groups release];
	_groups = [[[_listeners allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_listeners objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:indexPath.section] objectAtIndex:indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_groups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_groups objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [[self groupAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	cell.textLabel.text = [LASharedActivator localizedTitleForListenerName:listenerName];
	cell.detailTextLabel.text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
	cell.imageView.image = [LASharedActivator smallIconForListenerName:listenerName];
	[_delegate dataSource:self appliedContentToCell:cell forListenerWithName:listenerName];
	return cell;
}

@end
