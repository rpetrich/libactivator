#import "libactivator.h"

#import <notify.h>
#include <sys/stat.h>

#define CGRectZero ({ \
	CGRect zeroFrame; \
	zeroFrame.origin.x = 0.0f; \
	zeroFrame.origin.y = 0.0f; \
	zeroFrame.size.width = 0.0f; \
	zeroFrame.size.height = 0.0f; \
	zeroFrame; \
})


#define kPreferencesFilePath "/User/Library/Preferences/libactivator.plist"

@interface LAListenerSettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
@end

@implementation LAListenerSettingsViewController 

- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:@kPreferencesFilePath];
		if (!_preferences)
			_preferences = [[NSMutableDictionary alloc] init];
		BOOL showHidden = [[_preferences objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		_eventData = [[NSMutableDictionary alloc] init];
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Events" error:NULL]) {
			if (![fileName hasPrefix:@"."]) {
				NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/Library/Activator/Events/%@/Info.plist", fileName]];
				[_eventData setObject:infoDict forKey:fileName];
				if (!([[infoDict objectForKey:@"hidden"] boolValue] || showHidden)) {
					id key = [infoDict objectForKey:@"group"]?:@"";
					NSMutableArray *groupList = [_events objectForKey:key];
					if (!groupList) {
						groupList = [NSMutableArray array];
						[_events setObject:groupList forKey:key];
					}
					[groupList addObject:fileName];
				}
				[infoDict release];
			}
		}
	}
	return self;
}

- (void)dealloc
{
	[_preferences release];
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

- (void)_writePreferences
{
	[_preferences writeToFile:@kPreferencesFilePath atomically:YES];
	chmod(kPreferencesFilePath, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
	notify_post("libactivator.preferenceschanged");
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
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
	UITableViewCellAccessoryType accessory;
	if ([[_preferences objectForKey:preferenceName] isEqualToString:_listenerName])
		accessory = UITableViewCellAccessoryCheckmark;
	else 
		accessory = UITableViewCellAccessoryNone;
	[cell setAccessoryType:accessory];
	NSDictionary *infoPlist = [_eventData objectForKey:eventName];
	[cell setText:[infoPlist objectForKey:@"title"]];
	if ([[infoPlist objectForKey:@"hidden"] boolValue]) {
		[cell setTextColor:[[UIColor darkTextColor] colorWithAlphaComponent:0.75f]];
		[cell setSelectedTextColor:[[UIColor lightTextColor] colorWithAlphaComponent:0.75f]];
	} else {
		[cell setTextColor:nil];
		[cell setSelectedTextColor:nil];
	}
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UITableViewCellAccessoryType accessory = [cell accessoryType];
	NSInteger row = [indexPath row];
	NSString *eventName = [[self groupAtIndex:[indexPath section]] objectAtIndex:row];
	NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
	if (accessory == UITableViewCellAccessoryNone) {
		NSString *currentValue = [_preferences objectForKey:preferenceName];
		if ([currentValue length] && ![currentValue isEqualToString:_listenerName]) {
			NSDictionary *listenerInfo = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/Library/Activator/Listeners/%@/Info.plist", currentValue]];
			NSString *currentTitle = [listenerInfo objectForKey:@"title"];
			NSString *alertTitle = [@"Already assigned to\n" stringByAppendingString:currentTitle?:currentValue];
			UIAlertView *av = [[UIAlertView alloc] initWithTitle:alertTitle message:@"Only one action can be assigned\nto each event." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Reassign", nil];
			[av show];
			[av release];
			[self retain];
			return;
		}
		accessory = UITableViewCellAccessoryCheckmark;
		[_preferences setObject:_listenerName forKey:preferenceName];
	} else {
		accessory = UITableViewCellAccessoryNone;
		[_preferences removeObjectForKey:preferenceName];
	}
	[self _writePreferences];
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
		NSString *preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
		[_preferences setObject:_listenerName forKey:preferenceName];
		[self _writePreferences];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];		
	}
	[cell setSelected:NO animated:YES];
	[self release];
}


@end
