#import "Settings.h"
#import "libactivator-private.h"

#ifndef SINGLE
static NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[LASharedActivator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[LASharedActivator localizedTitleForEventName:b]];
}
#endif

@implementation LAModeSettingsController (API)

- (id)initWithMode:(NSString *)mode
{
	if ((self = [super init])) {
		_eventMode = [mode copy];
		_resolvedModes = [_eventMode ? [NSArray arrayWithObject:_eventMode] : [LASharedActivator availableEventModes] retain];
		self.navigationItem.title = [LASharedActivator localizedTitleForEventMode:_eventMode];
		BOOL showHidden = [[LASharedActivator _getObjectForPreference:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		if (mode) {
			for (NSString *eventName in [LASharedActivator availableEventNames]) {
				if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:mode]) {
					if (!([LASharedActivator eventWithNameIsHidden:eventName] || showHidden)) {
						NSString *key = [LASharedActivator localizedGroupForEventName:eventName] ?: @"";
						NSMutableArray *groupList = [_events objectForKey:key];
						if (!groupList) {
							groupList = [NSMutableArray array];
							[_events setObject:groupList forKey:key];
						}
						[groupList addObject:eventName];
					}
				}
			}
		} else {
			for (NSString *eventName in [LASharedActivator availableEventNames]) {
				if (!([LASharedActivator eventWithNameIsHidden:eventName] || showHidden)) {
					NSString *key = [LASharedActivator localizedGroupForEventName:eventName] ?: @"";
					NSMutableArray *groupList = [_events objectForKey:key];
					if (!groupList) {
						groupList = [NSMutableArray array];
						[_events setObject:groupList forKey:key];
					}
					[groupList addObject:eventName];
				}
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
	[_resolvedModes release];
	[_groups release];
	[_events release];
	[_eventMode release];
	[super dealloc];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_events objectForKey:[_groups objectAtIndex:index]];
}

- (BOOL)groupAtIndexIsLarge:(NSInteger)index
{
	return [[self groupAtIndex:index] count] > 11;
}

- (NSString *)eventNameForIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_groups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [self groupAtIndexIsLarge:section] ? nil : [_groups objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [self groupAtIndexIsLarge:section] ? 1 : [[self groupAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	UILabel *label = [cell textLabel];
	UILabel *detailLabel = [cell detailTextLabel];
	CGFloat alpha;
	NSInteger section = indexPath.section;
	if ([self groupAtIndexIsLarge:section]) {
		label.text = [_groups objectAtIndex:section];
		NSString *template = [LASharedActivator localizedStringForKey:@"N_ADDITIONAL_EVENTS" value:@"%i additional events"];
		detailLabel.text = [NSString stringWithFormat:template, [[self groupAtIndex:section] count]];
		alpha = 1.0f;		
	} else {
		NSString *eventName = [self eventNameForIndexPath:indexPath];
		label.text = [LASharedActivator localizedTitleForEventName:eventName];
		detailLabel.text = [LASharedActivator localizedDescriptionForEventName:eventName];
		alpha = 2.0f / 3.0f;
		for (NSString *mode in _resolvedModes) {
			if ([LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]]) {
				alpha = 1.0f;
				break;
			}
		}
	}
	detailLabel.alpha = alpha;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	LASettingsViewController *vc;
	if ([self groupAtIndexIsLarge:indexPath.section])
		vc = [[LAEventGroupSettingsController alloc] initWithModes:_resolvedModes events:[self groupAtIndex:indexPath.section] groupName:[_groups objectAtIndex:indexPath.section]];
	else
		vc = [[LAEventSettingsController alloc] initWithModes:_resolvedModes eventName:[self eventNameForIndexPath:indexPath]];
	[self pushSettingsController:vc];
	[vc release];
}

@end
