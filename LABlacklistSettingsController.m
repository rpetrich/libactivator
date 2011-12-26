#import "LABlacklistSettingsController.h"

#import "libactivator-private.h"

@implementation LABlacklistSettingsController

- (id)init
{
	if ((self = [super init])) {
		self.navigationItem.title = [LASharedActivator localizedStringForKey:@"BLACKLIST" value:@"Blacklist"];
		// Should actually retrieve application list directly, but this works
		NSDictionary *listeners = [LASharedActivator _cachedAndSortedListeners];
		systemAppsTitle = [[LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_System Applications" value:@"System Applications"] retain];
		systemApps = [[listeners objectForKey:systemAppsTitle] retain];
		userAppsTitle = [[LASharedActivator localizedStringForKey:@"LISTENER_GROUP_TITLE_User Applications" value:@"User Applications"] retain];
		userApps = [[listeners objectForKey:userAppsTitle] retain];
	}
	return self;
}

- (void)dealloc
{
	[userApps release];
	[userAppsTitle release];
	[systemApps release];
	[systemAppsTitle release];
	[super dealloc];
}

- (void)loadView
{
	[super loadView];
	_tableView.rowHeight = 44.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [userApps count] ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return section ? userAppsTitle : systemAppsTitle;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [section ? userApps : systemApps count];
}

- (NSString *)displayIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [indexPath.section ? userApps : systemApps objectAtIndex:indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"] autorelease];
	NSString *displayIdentifier = [self displayIdentifierForRowAtIndexPath:indexPath];
	cell.textLabel.text = [LASharedActivator localizedTitleForListenerName:displayIdentifier];
	cell.imageView.image = [LASharedActivator smallIconForListenerName:displayIdentifier];
	cell.accessoryType = [LASharedActivator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *displayIdentifier = [self displayIdentifierForRowAtIndexPath:indexPath];
	BOOL blacklisted = ![LASharedActivator applicationWithDisplayIdentifierIsBlacklisted:displayIdentifier];
	[LASharedActivator setApplicationWithDisplayIdentifier:displayIdentifier isBlacklisted:blacklisted];
	[tableView cellForRowAtIndexPath:indexPath].accessoryType = blacklisted ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end
