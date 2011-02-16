#import "LAListenerTableViewDataSource.h"
#import "libactivator-private.h"

@implementation LAListenerTableViewDataSource

- (void)dealloc
{
	[_searchText release];
	[_filteredListeners release];
	[_filteredGroups release];
	[_listeners release];
	[_groups release];
	[super dealloc];
}

- (void)updateFilteredListeners
{
	[_filteredGroups release];
	[_filteredListeners release];
	if ([_searchText length]) {
		_filteredListeners = [[NSMutableDictionary alloc] init];
		NSMutableArray *groups = [[NSMutableArray alloc] init];
		_filteredGroups = groups;
		for (NSString *groupName in [_listeners allKeys]) {
			if ([groupName rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
				[_filteredListeners setObject:[_listeners objectForKey:groupName] forKey:groupName];
				[groups addObject:groupName];
				continue;
			}
			NSMutableArray *mutableGroup = [NSMutableArray array];
			for (NSString *listenerName in [_listeners objectForKey:groupName]) {
				NSString *text;
				text = [LASharedActivator localizedTitleForListenerName:listenerName];
				if (text && [text rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
					[mutableGroup addObject:listenerName];
					continue;
				}
				text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
				if (text && [text rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
					[mutableGroup addObject:listenerName];
					continue;
				}
			}
			if ([mutableGroup count]) {
				[groups addObject:groupName];
				[_filteredListeners setObject:mutableGroup forKey:groupName];
			}
		}
	} else {
		_filteredListeners = [_listeners retain];
		_filteredGroups = [_groups mutableCopy];
	}
}

- (void)refineFilteredListeners
{
	for (NSString *groupName in [_filteredListeners allKeys]) {
		if ([groupName rangeOfString:_searchText options:NSCaseInsensitiveSearch].location == NSNotFound) {
			NSMutableArray *mutableGroup = [NSMutableArray array];
			for (NSString *listenerName in [_filteredListeners objectForKey:groupName]) {
				NSString *text;
				text = [LASharedActivator localizedTitleForListenerName:listenerName];
				if (text && [text rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
					[mutableGroup addObject:listenerName];
					continue;
				}
				text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
				if (text && [text rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
					[mutableGroup addObject:listenerName];
					continue;
				}
			}
			if ([mutableGroup count])
				[_filteredListeners setObject:mutableGroup forKey:groupName];
			else
				[_filteredGroups removeObject:groupName];
		}
	}
}

- (id<LAListenerTableViewDataSourceDelegate>)delegate
{
	return _delegate;
}

- (void)setDelegate:(id<LAListenerTableViewDataSourceDelegate>)delegate
{
	_delegate = delegate;
	[_listeners release];
	[_groups release];
	if (!delegate) {
		_listeners = nil;
		_groups = nil;
	} else {
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
		_groups = [[[_listeners allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
	}
	[self updateFilteredListeners];
}

- (NSString *)searchText
{
	return _searchText;
}

- (void)setSearchText:(NSString *)searchText
{
	if (_searchText != searchText) {
		BOOL refinedSearch = _searchText && searchText && [searchText rangeOfString:_searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
		[_searchText release];
		_searchText = [searchText copy];
		if (refinedSearch)
			[self refineFilteredListeners];
		else
			[self updateFilteredListeners];
	}
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_filteredListeners objectForKey:[_filteredGroups objectAtIndex:index]];
}

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:indexPath.section] objectAtIndex:indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_filteredGroups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_filteredGroups objectAtIndex:section];
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
