#import "LAMenuItemsController.h"
#import "LAMenuListenerSelectionController.h"
#import "libactivator-private.h"

@implementation LAMenuItemsController

- (void)dealloc
{
	[vc removeObserver:self forKeyPath:@"selectedListenerName"];
	[vc release];
	[_items release];
	[super dealloc];
}

- (NSArray *)items
{
	return [[_items copy] autorelease];
}

- (void)setItems:(NSArray *)items
{
	[_items release];
	_items = [items mutableCopy];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return [_items count];
		case 1:
			return 1;
		default:
			return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	switch (indexPath.section) {
		case 0: {
			NSString *listenerName = [_items objectAtIndex:indexPath.row];
			cell.textLabel.text = [LASharedActivator localizedTitleForListenerName:listenerName];
			cell.detailTextLabel.text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
			cell.imageView.image = [LASharedActivator smallIconForListenerName:listenerName];
			break;
		}
		case 1:
			cell.textLabel.text = [LASharedActivator localizedStringForKey:@"ADD_ACTION" value:@"Add Action"];
			cell.detailTextLabel.text = nil;
			cell.imageView.image = nil;
			break;
	}
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;	
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath.section == 0;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.section) {
		case 0:
			return UITableViewCellEditingStyleDelete;
		default:
			return UITableViewCellEditingStyleInsert;
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self willChangeValueForKey:@"items"];
	[_items removeObjectAtIndex:indexPath.row];
	[self didChangeValueForKey:@"items"];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	[vc removeObserver:self forKeyPath:@"selectedListenerName"];
	[vc release];
	vc = [[LAMenuListenerSelectionController alloc] init];
	vc.navigationItem.title = [LASharedActivator localizedStringForKey:@"ACTION" value:@"Action"];
	if (indexPath.section == 1)
		destinationIndex = -1;
	else {
		vc.selectedListenerName = [_items objectAtIndex:indexPath.row];
		destinationIndex = indexPath.row;
	}
	[vc addObserver:self forKeyPath:@"selectedListenerName" options:NSKeyValueObservingOptionNew context:NULL];
	[self pushSettingsController:vc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSString *listenerName = [change objectForKey:NSKeyValueChangeNewKey];
	[self willChangeValueForKey:@"items"];
	if (destinationIndex == -1) {
		[_items addObject:listenerName];
		destinationIndex = [_items count] - 1;
		[self didChangeValueForKey:@"items"];
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:destinationIndex inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
	} else {
		[_items replaceObjectAtIndex:destinationIndex withObject:listenerName];
		[self didChangeValueForKey:@"items"];
		[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:destinationIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
	}	
}

@end
