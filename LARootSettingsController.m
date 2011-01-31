#import "libactivator-private.h"
#import "ActivatorAdController.h"
#import "LAMenuSettingsController.h"

@interface LARootSettingsController () <UIAlertViewDelegate>
@end

@implementation LARootSettingsController

- (id)init
{
	if ((self = [super init])) {
		self.navigationItem.title = [LASharedActivator localizedStringForKey:@"ACTIVATOR" value:@"Activator"];
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return 1;
		case 1:
			return [[LASharedActivator availableEventModes] count];
		case 2:
			return 3;
		case 3:
			return 1;
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section) {
		case 3:
			return [LASharedActivator localizedStringForKey:@"LOCALIZATION_ABOUT" value:@""];
		case 4:
			return @"\u00A9 2009-2011 Ryan Petrich";
		default:
			return nil;
	}
}

- (NSString *)eventModeForIndexPath:(NSIndexPath *)indexPath
{
	switch ([indexPath section]) {
		case 1:
			return [[LASharedActivator availableEventModes] objectAtIndex:[indexPath row]];
		default:
			return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	switch (indexPath.section) {
		case 0:
		case 1: {
			NSString *eventMode = [self eventModeForIndexPath:indexPath];
			cell.textLabel.text = [LASharedActivator localizedTitleForEventMode:eventMode];
			cell.detailTextLabel.text = [LASharedActivator localizedDescriptionForEventMode:eventMode];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
		}
		case 2:
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			switch (indexPath.row) {
				case 0:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS_DETAIL" value:@"Get more actions via Cydia"];
					break;
				case 1:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"DONATE" value:@"Donate"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"DONATE_DETAIL" value:@"Contribute via PayPal"];
					break;
				case 2:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"MENUS" value:@"Menus"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"MENUS_DETAIL" value:@"Manage custom Activator menus"];
					break;
			}
			break;
		case 3:
			cell.textLabel.text = [LASharedActivator localizedStringForKey:@"RESET_SETTINGS" value:@"Reset Settings"];
			cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"RESET_SETTINGS_DETAIL" value:@"Return all settings to the default values"];
			cell.accessoryType = UITableViewCellAccessoryNone;
			break;
	}
	return cell;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != alertView.cancelButtonIndex)
		[LASharedActivator _resetPreferences];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	LASettingsViewController *vc;
	switch (indexPath.section) {
		case 0:
		case 1:
			vc = [[LAModeSettingsController alloc] initWithMode:[self eventModeForIndexPath:indexPath]];
			break;
		case 2:
			switch (indexPath.row) {
				case 0: {
					LAWebSettingsController *wsc = [[LAWebSettingsController alloc] init];
					[wsc loadURL:[LASharedActivator moreActionsURL]];
					wsc.navigationItem.title = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"];
					vc = wsc;
					break;
				}
				case 1:
					// Hide ads and show donation form
					[LASharedActivator _setObject:(id)kCFBooleanTrue forPreference:@"LAHideAds"];
					[[objc_getClass("ActivatorAdController") sharedInstance] hideAnimated:NO];
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://rpetri.ch/cydia/activator/donate/"]];
					return;
				case 2:
					vc = [[LAMenuSettingsController alloc] init];
					break;
				default:
					return;
			}
			break;
		default: {
			UIAlertView *av = [[UIAlertView alloc] initWithTitle:[LASharedActivator localizedStringForKey:@"RESET_ALERT_TITLE" value:@"Reset Activator Settings"] message:[LASharedActivator localizedStringForKey:@"RESET_ALERT_MESSAGE" value:@"Are you sure you wish to reset Activator settings to defaults?\nYour device will respring if you continue."] delegate:self cancelButtonTitle:[LASharedActivator localizedStringForKey:@"RESET_ALERT_CANCEL" value:@"Cancel"] otherButtonTitles:[LASharedActivator localizedStringForKey:@"RESET_ALERT_CONTINUE" value:@"Reset"], nil];
			[av show];
			[av release];
			return;
		}
	}
	[self pushSettingsController:vc];
	[vc release];
}

@end
