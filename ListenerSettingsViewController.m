#import "libactivator.h"

@interface LAListenerSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
@end

static LAActivator *activator;

NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[activator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[activator localizedTitleForEventName:b]];
}

@implementation LAListenerSettingsViewController 

- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		activator = [LAActivator sharedInstance];
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:[activator settingsFilePath]] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		for (NSString *eventName in [activator availableEventNames]) {
			if (!([activator eventWithNameIsHidden:eventName] || showHidden)) {
				NSString *key = [activator localizedGroupForEventName:eventName]?:@"";
				NSMutableArray *groupList = [_events objectForKey:key];
				if (!groupList) {
					groupList = [NSMutableArray array];
					[_events setObject:groupList forKey:key];
				}
				[groupList addObject:eventName];
			}
		}
		NSArray *groupNames = [_events allKeys];
		for (NSString *key in groupNames)
			[[_events objectForKey:key] sortUsingFunction:CompareEventNamesCallback context:nil];
		_groups = [[groupNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
	}
	return self;
}

- (void)dealloc
{
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
		if ([self isViewLoaded])
			[(UITableView *)[self view] reloadData];
	}
}

- (void)loadView
{
	UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
	[tableView setRowHeight:60.0f];
	[tableView setDelegate:self];
	[tableView setDataSource:self];
	[self setView:tableView];
	[tableView release];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_events objectForKey:[_groups objectAtIndex:index]];
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
	for (NSString *mode in [activator compatibleEventModesForListenerWithName:_listenerName]) {
		NSString *assignedName = [activator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]];
		if ([assignedName isEqual:name])
			[result addObject:mode];
	}
	return result;
}

- (BOOL)allowedToUnassignEvent:(NSString *)eventName fromListener:(NSString *)listenerName
{
	if (![activator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[activator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in [activator compatibleEventModesForListenerWithName:_listenerName])
		if ([[activator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]] isEqual:listenerName])
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
	CGFloat alpha = [activator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = [cell textLabel];
	[label setText:[activator localizedTitleForEventName:eventName]];
	[label setAlpha:alpha];
	UILabel *detailLabel = [cell detailTextLabel];
	[detailLabel setText:[activator localizedDescriptionForEventName:eventName]];
	[detailLabel setAlpha:alpha];
	return cell;
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSString *title = [activator localizedStringForKey:@"CANT_DEACTIVATE_REMAINING" value:@"Can't deactivate\nremaining event"];
	NSString *message = [NSString stringWithFormat:[activator localizedStringForKey:@"AT_LEAST_ONE_ASSIGNMENT_REQUIRED" value:@"At least one event must be\nassigned to %@"], [activator localizedTitleForListenerName:listenerName]];
	NSString *cancelButtonTitle = [activator localizedStringForKey:@"ALERT_OK" value:@"OK"];
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
	for (NSString *mode in [activator compatibleEventModesForListenerWithName:_listenerName])
		if ([activator eventWithName:eventName isCompatibleWithMode:mode])
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
			[activator unassignEvent:[LAEvent eventWithName:eventName mode:mode]];
		[cell setAccessoryType:UITableViewCellAccessoryNone];
	} else {
		// Check if allowed to unassign other listeners. if not bail
		NSMutableArray *otherTitles = [NSMutableArray array];
		for (NSString *mode in compatibleModes) {
			NSString *otherListener = [activator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:_listenerName]) {
				NSString *otherTitle = [activator localizedTitleForListenerName:otherListener];
				if (![otherTitles containsObject:otherTitle])
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
			NSString *separator = [activator localizedStringForKey:@"ALERT_VALUE_AND" value:@" and "];
			NSString *alertTitle = [NSString stringWithFormat:[activator localizedStringForKey:@"ALREADY_ASSIGNED_TO" value:@"Already assigned to\n%@"], [otherTitles componentsJoinedByString:separator]];
			NSString *cancelButtonTitle = [activator localizedStringForKey:@"ALERT_CANCEL" value:@"Cancel"];
			NSString *reassignButtonTitle = [activator localizedStringForKey:@"ALERT_REASSIGN" value:@"Reassign"];
			UIAlertView *av = [[UIAlertView alloc] initWithTitle:alertTitle message:nil delegate:self cancelButtonTitle:cancelButtonTitle otherButtonTitles:reassignButtonTitle, nil];
			[av show];
			[av release];
			[self retain];
			return;
		}
		// Assign and update cell accessory
		for (NSString *mode in compatibleModes)
			[activator assignEvent:[LAEvent eventWithName:eventName mode:mode] toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	UITableView *tableView = (UITableView *)[self view];
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	if (buttonIndex != [alertView cancelButtonIndex]) {
		for (NSString *mode in [activator compatibleEventModesForListenerWithName:_listenerName])
			[activator assignEvent:[LAEvent eventWithName:eventName mode:mode] toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self release];
}


@end
