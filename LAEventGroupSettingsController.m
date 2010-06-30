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
	CGFloat alpha = [LASharedActivator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = cell.textLabel;
	label.text = [LASharedActivator localizedTitleForEventName:eventName];
	label.alpha = alpha;
	UILabel *detailLabel = cell.detailTextLabel;
	detailLabel.text = [LASharedActivator localizedDescriptionForEventName:eventName];
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
