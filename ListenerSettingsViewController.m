#import "libactivator.h"

#define kPreferencesFilePath "/User/Library/Preferences/libactivator.plist"

@interface LAListenerSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
@end

@implementation LAListenerSettingsViewController 

- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:@kPreferencesFilePath] objectForKey:@"LAShowHiddenEvents"] boolValue];
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
	NSString *assignedListenerName = [[LAActivator sharedInstance] assignedListenerNameForEventName:eventName];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UITableViewCellAccessoryType accessory = [cell accessoryType];
	NSInteger row = [indexPath row];
	NSString *eventName = [[self groupAtIndex:[indexPath section]] objectAtIndex:row];
	if (accessory == UITableViewCellAccessoryNone) {
		NSString *currentValue = [[LAActivator sharedInstance] assignedListenerNameForEventName:eventName];
		if ([currentValue length] && ![currentValue isEqualToString:_listenerName]) {
			NSDictionary *listenerInfo = [[LAActivator sharedInstance] infoForListenerWithName:currentValue];
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
		accessory = UITableViewCellAccessoryCheckmark;
		[[LAActivator sharedInstance] assignEventName:eventName toListenerWithName:_listenerName];
	} else {
		accessory = UITableViewCellAccessoryNone;
		[[LAActivator sharedInstance] unassignEventName:eventName];
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
		[[LAActivator sharedInstance] assignEventName:eventName toListenerWithName:_listenerName];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];		
	}
	[cell setSelected:NO animated:YES];
	[self release];
}


@end
