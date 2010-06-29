#import "libactivator.h"
#import "libactivator-private.h"

@interface LAListenerSettingsViewController () <UIAlertViewDelegate>
@end

static NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[LASharedActivator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[LASharedActivator localizedTitleForEventName:b]];
}

@implementation LAListenerSettingsViewController 

- (id)init
{
	if ((self = [super init])) {
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:[LASharedActivator settingsFilePath]] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		for (NSString *eventName in [LASharedActivator availableEventNames]) {
			if (!([LASharedActivator eventWithNameIsHidden:eventName] || showHidden)) {
				NSString *key = [LASharedActivator localizedGroupForEventName:eventName]?:@"";
				NSMutableArray *groupList = [_events objectForKey:key];
				if (!groupList) {
					groupList = [NSMutableArray array];
					[_events setObject:groupList forKey:key];
				}
				[groupList addObject:eventName];
			}
		}
		_compatibleEvents = [[NSMutableDictionary alloc] init];
		NSArray *groupNames = [_events allKeys];
		for (NSString *key in groupNames)
			[[_events objectForKey:key] sortUsingFunction:CompareEventNamesCallback context:nil];
		_groups = [[groupNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
	}
	return self;
}

- (void)dealloc
{
	[_compatibleEvents release];
	[_groups release];
	[_listenerName release];
	[_eventMode release];
	[_events release];
	[super dealloc];
}

- (NSString *)listenerName
{
	return _listenerName;
}

- (void)setListenerName:(NSString *)listenerName
{
	if (![_listenerName isEqual:listenerName]) {
		[_listenerName release];
		_listenerName = [listenerName copy];
		for (NSString *group in _groups) {
			NSMutableArray *events = [NSMutableArray array];
			for (NSString *eventName in [_events objectForKey:group])
				if ([LASharedActivator listenerWithName:_listenerName isCompatibleWithEventName:eventName])
					[events addObject:eventName];
			[_compatibleEvents setObject:events forKey:group];
		}
		if ([self isViewLoaded])
			[self.tableView reloadData];
	}
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_compatibleEvents objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)eventNameForRowAtIndexPath:(NSIndexPath *)indexPath
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

- (NSArray *)compatibleModesAssignedToListener:(NSString *)name eventName:(NSString *)eventName
{
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *mode in [LASharedActivator compatibleEventModesForListenerWithName:_listenerName]) {
		NSString *assignedName = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]];
		if ([assignedName isEqual:name])
			[result addObject:mode];
	}
	return result;
}

- (BOOL)allowedToUnassignEvent:(NSString *)eventName fromListener:(NSString *)listenerName
{
	if (![LASharedActivator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[LASharedActivator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in [LASharedActivator compatibleEventModesForListenerWithName:_listenerName])
		if ([[LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;	
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (!cell)
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	[cell setAccessoryType:
		[[self compatibleModesAssignedToListener:_listenerName eventName:eventName] count] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone];
	CGFloat alpha = [LASharedActivator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = [cell textLabel];
	[label setText:[LASharedActivator localizedTitleForEventName:eventName]];
	[label setAlpha:alpha];
	UILabel *detailLabel = [cell detailTextLabel];
	[detailLabel setText:[LASharedActivator localizedDescriptionForEventName:eventName]];
	[detailLabel setAlpha:alpha];
	return cell;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	// Find compatible modes
	NSMutableArray *compatibleModes = [NSMutableArray array];
	for (NSString *mode in [LASharedActivator compatibleEventModesForListenerWithName:_listenerName])
		if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:mode])
			[compatibleModes addObject:mode];
	NSArray *assigned = [self compatibleModesAssignedToListener:_listenerName eventName:eventName];
	if ([assigned count] == [compatibleModes count]) {
		// Check if allowed to unassign. if not bail
		if (![self allowedToUnassignEvent:eventName fromListener:_listenerName]) {
			[self showLastEventMessageForListener:_listenerName];
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
			return;
		}
		// Unassign and update cell accessory
		for (NSString *mode in assigned)
			[LASharedActivator unassignEvent:[LAEvent eventWithName:eventName mode:mode]];
		[cell setAccessoryType:UITableViewCellAccessoryNone];
	} else {
		// Check if allowed to unassign other listeners. if not bail
		NSMutableArray *otherTitles = [NSMutableArray array];
		for (NSString *mode in compatibleModes) {
			NSString *otherListener = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:_listenerName]) {
				NSString *otherTitle = [LASharedActivator localizedTitleForListenerName:otherListener];
				if (otherTitle && ![otherTitles containsObject:otherTitle])
					[otherTitles addObject:otherTitle];
				if (![self allowedToUnassignEvent:eventName fromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					[tableView deselectRowAtIndexPath:indexPath animated:YES];
					return;
				}
			}
		}
		// Show Reassign message if necessary
		if ([otherTitles count]) {
			NSString *separator = [LASharedActivator localizedStringForKey:@"ALERT_VALUE_AND" value:@" and "];
			NSString *alertTitle = [NSString stringWithFormat:[LASharedActivator localizedStringForKey:@"ALREADY_ASSIGNED_TO" value:@"Already assigned to\n%@"], [otherTitles componentsJoinedByString:separator]];
			NSString *cancelButtonTitle = [LASharedActivator localizedStringForKey:@"ALERT_CANCEL" value:@"Cancel"];
			NSString *reassignButtonTitle = [LASharedActivator localizedStringForKey:@"ALERT_REASSIGN" value:@"Reassign"];
			UIAlertView *av = [[UIAlertView alloc] initWithTitle:alertTitle message:nil delegate:self cancelButtonTitle:cancelButtonTitle otherButtonTitles:reassignButtonTitle, nil];
			[av show];
			[av release];
			[self retain];
			return;
		}
		// Assign and update cell accessory
		for (NSString *mode in compatibleModes)
			[LASharedActivator assignEvent:[LAEvent eventWithName:eventName mode:mode] toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	UITableView *tableView = self.tableView;
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	if (buttonIndex != [alertView cancelButtonIndex]) {
		for (NSString *mode in [LASharedActivator compatibleEventModesForListenerWithName:_listenerName])
			[LASharedActivator assignEvent:[LAEvent eventWithName:eventName mode:mode] toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self release];
}


@end
