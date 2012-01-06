#import "Settings.h"
#import "libactivator-private.h"
#import "LAMenuSettingsController.h"
#import "LABlacklistSettingsController.h"
#include <dlfcn.h>
#include <notify.h>
#include <sys/stat.h>
#import <UIKit/UIKit2.h>

static BOOL shouldLaunchCydia;

@interface LARootSettingsController () <UIAlertViewDelegate>
@end

@implementation LARootSettingsController (API)

- (id)init
{
	if ((self = [super init])) {
		self.navigationItem.title = [LASharedActivator localizedStringForKey:@"ACTIVATOR" value:@"Activator"];
		void *lh = dlopen("/usr/lib/hide.dylib", RTLD_LAZY);
		libhide = lh;
		libhideIsHidden = dlsym(lh, "IsIconHiddenDisplayId");
	}
	return self;
}

static inline int PermissionsForFile(const char *path)
{
	struct stat buf;
	return (stat(path, &buf) == 0) ? ({ NSLog(@"Activator: mode of %s is %d", path, buf.st_mode); buf.st_mode; }) : 0;
}

- (void)loadView
{
	if (!LASharedActivator.alive) {
		UIAlertView *av;
		if (((PermissionsForFile("/usr/lib/libactivator.dylib") & 0755) == 0755) &&
			((PermissionsForFile("/Library/MobileSubstrate/DynamicLibraries/Activator.dylib") & 0755) == 0755) &&
			((PermissionsForFile("/Library/Activator/SpringBoard.dylib") & 0755) == 0755)
		) {
			shouldLaunchCydia = NO;
			av = [[UIAlertView alloc] initWithTitle:[LASharedActivator localizedStringForKey:@"ACTIVATOR_DISABLED" value:@"Activator Disabled"] message:[LASharedActivator localizedStringForKey:@"ACTIVATOR_DISABLED_MESSAGE" value:@"Most features of Activator are currently disabled because Mobile Substrate is not functioning. If your device is in Safe Mode, you will see \"Exit Safe Mode\" at the top of your screen, and you can tap \"Restart\" to return to normal mode."] delegate:self cancelButtonTitle:[LASharedActivator localizedStringForKey:@"SAFE_MODE_CANCEL" value:@"Cancel"] otherButtonTitles:[LASharedActivator localizedStringForKey:@"SAFE_MODE_RESTART" value:@"Restart"], nil];
		} else {
			shouldLaunchCydia = YES;
			av = [[UIAlertView alloc] initWithTitle:[LASharedActivator localizedStringForKey:@"ACTIVATOR_CORRUPT" value:@"Activator Corrupt"] message:[LASharedActivator localizedStringForKey:@"ACTIVATOR_CORRUPT_MESSAGE" value:@"Most features of Activator are currently disabled because Activator's internal files seem to be incorrect. Try going into Cydia and reinstalling Activator."] delegate:self cancelButtonTitle:[LASharedActivator localizedStringForKey:@"CORRUPT_CANCEL" value:@"Cancel"] otherButtonTitles:[LASharedActivator localizedStringForKey:@"CORRUPT_LAUNCH_CYDIA" value:@"Launch Cydia"], nil];
		}
		[av show];
		[av release];
	}
	[super loadView];
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
			return 4;
		case 3:
			return libhideIsHidden ? 2 : 1;
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
			return @"\u00A9 2009-2012 Ryan Petrich";
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
				case 3:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"BLACKLIST" value:@"Blacklist"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"BLACKLIST_DETAIL" value:@"Ignore events in specific applications"];
					break;
			}
			break;
		case 3:
			switch (indexPath.row) {
				case 0:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"RESET_SETTINGS" value:@"Reset Settings"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"RESET_SETTINGS_DETAIL" value:@"Return all settings to the default values"];
					cell.accessoryType = UITableViewCellAccessoryNone;
					break;
				case 1:
					cell.textLabel.text = [LASharedActivator localizedStringForKey:@"SHOW_ICON" value:@"Show Icon"];
					cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"SHOW_ACTIVATOR_ICON_ON_SPRINGBOARD" value:@"Show Activator Icon on SpringBoard"];
					cell.accessoryType = libhideIsHidden(@"libactivator") ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
					break;
			}
			break;
	}
	return cell;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != alertView.cancelButtonIndex) {
		if (LASharedActivator.alive)
			[LASharedActivator _resetPreferences];
		else {
			if (shouldLaunchCydia) {
				[UIApp openURL:[NSURL URLWithString:@"cydia://package/libactivator"]];
			} else {
				system("killall SpringBoard");
			}
		}
	}
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
					[LASettingsViewController updateAdSettings];
					[UIApp openURL:[NSURL URLWithString:@"http://rpetri.ch/cydia/activator/donate/"]];
					return;
				case 2:
					vc = [[LAMenuSettingsController alloc] init];
					break;
				case 3:
					vc = [[LABlacklistSettingsController alloc] init];
					break;
				default:
					return;
			}
			break;
		default: 
			switch (indexPath.row) {
				case 0: {
					UIAlertView *av = [[UIAlertView alloc] initWithTitle:[LASharedActivator localizedStringForKey:@"RESET_ALERT_TITLE" value:@"Reset Activator Settings"] message:[LASharedActivator localizedStringForKey:@"RESET_ALERT_MESSAGE" value:@"Are you sure you wish to reset Activator settings to defaults?\nYour device will respring if you continue."] delegate:self cancelButtonTitle:[LASharedActivator localizedStringForKey:@"RESET_ALERT_CANCEL" value:@"Cancel"] otherButtonTitles:[LASharedActivator localizedStringForKey:@"RESET_ALERT_CONTINUE" value:@"Reset"], nil];
					[av show];
					[av release];
					return;
				}
				default: {
					BOOL newValue = !libhideIsHidden(@"libactivator");
					[LASharedActivator _setObject:newValue ? (id)kCFBooleanTrue : (id)kCFBooleanFalse forPreference:@"LAHideIcon"];
					[tableView cellForRowAtIndexPath:indexPath].accessoryType = newValue ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
					BOOL (*libhideFunction)(NSString *) = dlsym(libhide, newValue ? "HideIconViaDisplayId" : "UnHideIconViaDisplayId");
					if (libhideFunction) {
						libhideFunction(@"libactivator");
						notify_post("com.libhide.hiddeniconschanged");
					}
					return;
				}
			}
	}
	[self pushSettingsController:vc];
	[vc release];
}

@end
