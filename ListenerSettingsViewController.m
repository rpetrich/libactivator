#import "libactivator.h"

@interface LAListenerSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
@end

static LAActivator *activator;

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
	}
	return self;
}

- (void)dealloc
{
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
	if (![_listenerName isEqualToString:listenerName]) {
		[_listenerName release];
		_listenerName = [listenerName copy];
		if ([self isViewLoaded])
			[(UITableView *)[self view] reloadData];
	}
}

- (void)loadView
{
	UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
	[tableView setDelegate:self];
	[tableView setDataSource:self];
	[self setView:tableView];
	[tableView release];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_events objectForKey:[[_events allKeys] objectAtIndex:index]];
}

- (NSString *)eventNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [[_events allKeys] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[_events allKeys] objectAtIndex:section];
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
		if ([assignedName isEqualToString:name])
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
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	[cell setAccessoryType:
		[[self compatibleModesAssignedToListener:_listenerName eventName:eventName] count] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone];
	UILabel *label = [cell textLabel];
	[label setText:[activator localizedTitleForEventName:eventName]];
	if ([activator eventWithNameIsHidden:eventName]) {
		[label setTextColor:[[UIColor darkTextColor] colorWithAlphaComponent:0.66f]];
		[label setHighlightedTextColor:[UIColor colorWithWhite:1.0f alpha:0.66f]];
	} else {
		[label setTextColor:[UIColor darkTextColor]];
		[label setHighlightedTextColor:[UIColor whiteColor]];
	}
	return cell;	
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Can't deactivate\nremaining event" message:[@"At least one event must be\nassigned to " stringByAppendingString:[activator localizedTitleForListenerName:listenerName]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *eventName = [self eventNameForRowAtIndexPath:indexPath];
	NSArray *compatibleModes = [activator compatibleEventModesForListenerWithName:_listenerName];
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
			if (otherListener && ![otherListener isEqualToString:_listenerName]) {
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
			NSString *alertTitle = [@"Already assigned to\n" stringByAppendingString:[otherTitles componentsJoinedByString:@" and "]];
			UIAlertView *av = [[UIAlertView alloc] initWithTitle:alertTitle message:@"Only one action can be assigned\nto each event." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Reassign", nil];
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
