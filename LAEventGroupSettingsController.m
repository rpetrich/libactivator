#import "Settings.h"
#import "libactivator-private.h"

@implementation LAEventGroupSettingsController

- (id)initWithModes:(NSArray *)modes events:(NSMutableArray *)events groupName:(NSString *)groupName
{
	if ((self = [super init])) {
		_modes = [modes copy];
		_events = [events copy];
		_groupName = [groupName copy];
		self.navigationItem.title = _groupName;
	}
	return self;
}

- (void)dealloc
{
	[_modes release];
	[_events release];
	[_groupName release];
	[super dealloc];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [_events count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *eventName = [_events objectAtIndex:indexPath.row];
	UILabel *label = cell.textLabel;
	label.text = [LASharedActivator localizedTitleForEventName:eventName];
	UILabel *detailLabel = cell.detailTextLabel;
	detailLabel.text = [LASharedActivator localizedDescriptionForEventName:eventName];
	CGFloat alpha = 2.0f / 3.0f;
	for (NSString *mode in _modes) {
		if ([LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:eventName mode:mode]]) {
			alpha = 1.0f;
			break;
		}
	}
	detailLabel.alpha = alpha;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	LASettingsViewController *vc = [[LAEventSettingsController alloc] initWithModes:_modes eventName:[_events objectAtIndex:indexPath.row]];
	[self pushSettingsController:vc];
	[vc release];
}

@end
