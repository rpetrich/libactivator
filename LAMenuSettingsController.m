#import "LAMenuSettingsController.h"
#import "LAMenuItemsController.h"
#import "libactivator-private.h"

#import <notify.h>

@interface LAMenuSettingsController () <UIAlertViewDelegate>
@end

@implementation LAMenuSettingsController

- (id)init
{
	if ((self = [super init])) {
		NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/libactivator.menu.plist"];
		menus = [[settings objectForKey:@"menus"] mutableCopy] ?: [[NSMutableDictionary alloc] init];
		sortedMenus = [[menus allKeys] mutableCopy];
		self.navigationItem.title = [LASharedActivator localizedStringForKey:@"MENUS" value:@"Menus"];
	}
	return self;
}

- (void)dealloc
{
	[vc removeObserver:self forKeyPath:@"items"];
	[vc release];
	[selectedMenu release];
	[sortedMenus release];
	[menus release];
	[super dealloc];
}

- (void)saveSettings
{
	[[NSDictionary dictionaryWithObject:menus forKey:@"menus"] writeToFile:@"/var/mobile/Library/Preferences/libactivator.menu.plist" atomically:YES];
	notify_post("libactivator.menu/settingschanged");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return [sortedMenus count];
		case 1:
			return 1;
		default:
			return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *title;
	switch (indexPath.section) {
		case 0: {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			NSString *key = [sortedMenus objectAtIndex:indexPath.row];
			title = [[menus objectForKey:key] objectForKey:@"title"];
			break;
		}
		case 1:
			cell.accessoryType = UITableViewCellAccessoryNone;
			title = [LASharedActivator localizedStringForKey:@"ADD_NEW_MENU" value:@"Add New Menu"];
			break;
		default:
			title = nil;
			break;
	}
	cell.textLabel.text = title;
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
	NSString *key = [sortedMenus objectAtIndex:indexPath.row];
	[menus removeObjectForKey:key];
	[sortedMenus removeObjectAtIndex:indexPath.row];
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
	[self saveSettings];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	switch (indexPath.section) {
		case 0: {
			NSString *key = [sortedMenus objectAtIndex:indexPath.row];
			NSDictionary *menuData = [menus objectForKey:key];
			[vc removeObserver:self forKeyPath:@"items"];
			[vc release];
			vc = [[LAMenuItemsController alloc] init];
			vc.navigationItem.title = [menuData objectForKey:@"title"];
			vc.items = [menuData objectForKey:@"items"];
			[selectedMenu release];
			selectedMenu = [key copy];
			[vc addObserver:self forKeyPath:@"items" options:NSKeyValueObservingOptionNew context:NULL];
			[self pushSettingsController:vc];
			break;
		}
		case 1: {
			UIAlertView *av = [[UIAlertView alloc] init];
			av.title = [LASharedActivator localizedStringForKey:@"NEW_MENU" value:@"New Menu"];
			[av addTextFieldWithValue:nil label:[LASharedActivator localizedStringForKey:@"MENU_TITLE" value:@"Menu Title"]];
			[av addButtonWithTitle:[LASharedActivator localizedStringForKey:@"ADD" value:@"Add"]];
			av.cancelButtonIndex = [av addButtonWithTitle:[LASharedActivator localizedStringForKey:@"CANCEL" value:@"Cancel"]];
			av.delegate = self;
			[av show];
			[av release];
			break;
		}
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != alertView.cancelButtonIndex) {
		UITextField *textField = [alertView textFieldAtIndex:0];
		NSString *title = textField.text ?: @"";
		NSDictionary *menu = [NSDictionary dictionaryWithObjectsAndKeys:
			title, @"title",
			[NSArray array], @"items",
		nil];
		NSString *newKey;
		do {
			CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
			newKey = [(id)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease];
			CFRelease(uuid);
			newKey = [@"libactivator.menu." stringByAppendingString:newKey];
		} while ([menus objectForKey:newKey]);
		[menus setObject:menu forKey:newKey];
		[sortedMenus addObject:newKey];
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[sortedMenus count] - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
		[self saveSettings];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSArray *items = [change objectForKey:NSKeyValueChangeNewKey];
	NSMutableDictionary *menuData = [[menus objectForKey:selectedMenu] mutableCopy];
	[menuData setObject:items forKey:@"items"];
	[menus setObject:menuData forKey:selectedMenu];
	[menuData release];
	[self saveSettings];
}

@end
