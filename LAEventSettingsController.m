#import "libactivator-private.h"
#import "ActivatorEventViewHeader.h"

@interface LAEventSettingsController () <ActivatorEventViewHeaderDelegate>
@end

@implementation LAEventSettingsController

- (void)updateHeader
{
	[_currentAssignments removeAllObjects];
	for (NSString *mode in _modes) {
		NSString *assigned = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		if (assigned)
			[_currentAssignments addObject:assigned];
	}
	_headerView.listenerNames = _currentAssignments;
	UITableView *tableView = self.tableView;
	CGRect frame = _headerView.frame;
	frame.size.width = tableView.bounds.size.width;
	_headerView.frame = frame;
	tableView.tableHeaderView = _headerView;
}

- (id)initWithModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super init])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		_currentAssignments = [[NSMutableSet alloc] init];
		_listeners = [[LASharedActivator _cachedAndSortedListeners] mutableCopy];
		for (NSString *key in [_listeners allKeys]) {
			NSArray *group = [_listeners objectForKey:key];
			NSMutableArray *mutableGroup = [NSMutableArray array];
			BOOL hasItems = NO;
			for (NSString *listenerName in group) {
				if ([LASharedActivator listenerWithName:listenerName isCompatibleWithEventName:eventName])
					for (NSString *mode in _modes)
						if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode]) {
							[mutableGroup addObject:listenerName];
							hasItems = YES;
							break;
						}
			}
			if (hasItems)
				[_listeners setObject:mutableGroup forKey:key];
			else
				[_listeners removeObjectForKey:key];
		}
		_groups = [[[_listeners allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
		_eventName = [eventName copy];
		self.navigationItem.title = [LASharedActivator localizedTitleForEventName:_eventName];
		CGRect headerFrame;
		headerFrame.origin.x = 0.0f;
		headerFrame.origin.y = 0.0f;
		headerFrame.size.width = 0.0f;
		headerFrame.size.height = 76.0f;
		_headerView = [[ActivatorEventViewHeader alloc] initWithFrame:headerFrame];
		_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_headerView.delegate = self;
		[self updateHeader];
	}
	return self;
}

- (void)dealloc
{
	_headerView.delegate = nil;
	[_headerView release];
	[_groups release];
	[_listeners release];
	[_eventName release];
	[_currentAssignments release];
	[_modes release];
	[super dealloc];
}

- (void)viewDidLoad
{
	[self updateHeader];
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSString *title = [LASharedActivator localizedStringForKey:@"CANT_DEACTIVATE_REMAINING" value:@"Can't deactivate\nremaining event"];
	NSString *message = [NSString stringWithFormat:[LASharedActivator localizedStringForKey:@"AT_LEAST_ONE_ASSIGNMENT_REQUIRED" value:@"At least one event must be\nassigned to %@"], [LASharedActivator localizedTitleForListenerName:listenerName]];
	NSString *cancelButtonTitle = [LASharedActivator localizedStringForKey:@"ALERT_OK" value:@"OK"];
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	[av show];
	[av release];
}

- (BOOL)allowedToUnassignEventsFromListener:(NSString *)listenerName
{
	if (![LASharedActivator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[LASharedActivator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in _modes)
		if ([[LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;
}

- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader
{
	NSMutableArray *events = [NSMutableArray array];
	for (NSString *mode in _modes) {
		LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
		NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
		if (listenerName) {
			if (![self allowedToUnassignEventsFromListener:listenerName]) {
				[self showLastEventMessageForListener:listenerName];
				return;
			}
			[events addObject:event];
		}
	}
	for (LAEvent *event in events)
		[LASharedActivator unassignEvent:event];
	for (UITableViewCell *cell in [[self tableView] visibleCells])
		cell.accessoryType = UITableViewCellAccessoryNone;
	eventViewHeader.listenerNames = nil;
	[self updateHeader];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_listeners objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
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

- (NSInteger)countOfModesAssignedToListener:(NSString *)name
{
	NSInteger result = 0;
	for (NSString *mode in _modes) {
		NSString *assignedName = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		result += [assignedName isEqual:name];
	}
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	cell.textLabel.text = [LASharedActivator localizedTitleForListenerName:listenerName];
	cell.detailTextLabel.text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
	cell.imageView.image = [LASharedActivator smallIconForListenerName:listenerName];
	BOOL assigned = [_currentAssignments containsObject:listenerName];
	cell.accessoryType = assigned ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	NSUInteger compatibleModeCount = 0;
	for (NSString *mode in _modes)
		if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode])
			compatibleModeCount++;
	BOOL allAssigned = [self countOfModesAssignedToListener:listenerName] >= compatibleModeCount;
	if (allAssigned) {
		if (![self allowedToUnassignEventsFromListener:listenerName]) {
			[self showLastEventMessageForListener:listenerName];
			return;
		}
		cell.accessoryType = UITableViewCellAccessoryNone;
		for (NSString *mode in _modes)
			[LASharedActivator unassignEvent:[LAEvent eventWithName:_eventName mode:mode]];
	} else {
		for (NSString *mode in _modes) {
			NSString *otherListener = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:listenerName]) {
				if (![self allowedToUnassignEventsFromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					return;
				}
			}
		}
		for (UITableViewCell *otherCell in [tableView visibleCells])
			otherCell.accessoryType = UITableViewCellAccessoryNone;
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		for (NSString *mode in _modes) {
			LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
			if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode])
				[LASharedActivator assignEvent:event toListenerWithName:listenerName];
			else
				[LASharedActivator unassignEvent:event];
		}
	}
	[self updateHeader];
}

@end
