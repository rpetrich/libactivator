#import "libactivator.h"

@interface LAListenerSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
@end

@implementation LAListenerSettingsViewController 

- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:LAActivatorSettingsFilePath] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_eventMode = [LAEventModeAny copy];
		_events = [[NSMutableDictionary alloc] init];
		_eventData = [[NSMutableDictionary alloc] init];
		LAActivator *la = [LAActivator sharedInstance];
		for (NSString *eventName in [la availableEventNames]) {
			NSDictionary *infoDict = [la infoForEventWithName:eventName];
			[_eventData setObject:infoDict forKey:eventName];
			if (!([[infoDict objectForKey:@"hidden"] boolValue] || showHidden)) {
				NSString *key = [infoDict objectForKey:@"group"]?:@"";
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
	[_eventData release];
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

- (NSString *)eventMode
{
	return _eventMode;
}
- (void)setEventMode:(NSString *)eventMode
{
	if (![_eventMode isEqualToString:eventMode]) {
		[_eventMode release];
		_eventMode = [eventMode copy];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"Cell"] autorelease];
	else
		[cell setSelected:NO animated:NO];
	NSInteger row = [indexPath row];
	NSString *eventName = [[self groupAtIndex:[indexPath section]] objectAtIndex:row];
	NSString *assignedListenerName = [[LAActivator sharedInstance] assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:_eventMode]];
	[cell setAccessoryType:([assignedListenerName isEqualToString:_listenerName])?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone];
	NSDictionary *infoPlist = [_eventData objectForKey:eventName];
	[cell setText:[infoPlist objectForKey:@"title"]];
	if ([[infoPlist objectForKey:@"hidden"] boolValue]) {
		[cell setTextColor:[[UIColor darkTextColor] colorWithAlphaComponent:0.75f]];
		[cell setSelectedTextColor:[UIColor colorWithWhite:1.0f alpha:0.75f]];
	} else {
		[cell setTextColor:[UIColor darkTextColor]];
		[cell setSelectedTextColor:[UIColor whiteColor]];
	}
	return cell;	
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSDictionary *info = [[LAActivator sharedInstance] infoForListenerWithName:listenerName];
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Can't deactivate\nremaining event" message:[@"At least one event must be\nassigned to " stringByAppendingString:[info objectForKey:@"title"]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	LAActivator *la = [LAActivator sharedInstance];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UITableViewCellAccessoryType accessory = [cell accessoryType];
	NSInteger row = [indexPath row];
	NSString *eventName = [[self groupAtIndex:[indexPath section]] objectAtIndex:row];
	LAEvent *event = [LAEvent eventWithName:eventName mode:_eventMode];
	if (accessory == UITableViewCellAccessoryNone) {
		NSString *currentValue = [la assignedListenerNameForEvent:event];
		NSDictionary *listenerInfo;
		if (![currentValue isEqualToString:_listenerName] && (listenerInfo = [la infoForListenerWithName:currentValue])) {
			BOOL requireEvent = [[listenerInfo objectForKey:@"require-event"] boolValue];
			if (requireEvent && [[la eventsAssignedToListenerWithName:currentValue] count] <= 1)
				[self showLastEventMessageForListener:currentValue];
			else {
				NSString *currentTitle = [listenerInfo objectForKey:@"title"];
				NSString *alertTitle = [@"Already assigned to\n" stringByAppendingString:currentTitle?:currentValue];
				UIAlertView *av;
				if ([[listenerInfo objectForKey:@"sticky"] boolValue])
					av = [[UIAlertView alloc] initWithTitle:alertTitle message:@"Only one action can be assigned\nto each event." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
				else
					av = [[UIAlertView alloc] initWithTitle:alertTitle message:@"Only one action can be assigned\nto each event." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Reassign", nil];
				[av show];
				[av release];
				[self retain];
				return;
			}
		} else {
			accessory = UITableViewCellAccessoryCheckmark;
			[[LAActivator sharedInstance] assignEvent:event toListenerWithName:_listenerName];
		}
	} else {
		BOOL requireEvent = [[[la infoForListenerWithName:_listenerName] objectForKey:@"require-event"] boolValue];
		if (requireEvent && [[la eventsAssignedToListenerWithName:_listenerName] count] <= 1) {
			[self showLastEventMessageForListener:_listenerName];
		} else {
			accessory = UITableViewCellAccessoryNone;
			[la unassignEvent:event];
		}
	}
	[cell setAccessoryType:accessory];
	[cell setSelected:NO animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	UITableView *tableView = (UITableView *)[self view];
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (buttonIndex != [alertView cancelButtonIndex]) {
		NSString *eventName = [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
		LAEvent *event = [LAEvent eventWithName:eventName mode:_eventMode];
		[[LAActivator sharedInstance] assignEvent:event toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];		
	}
	[cell setSelected:NO animated:YES];
	[self release];
}


@end
