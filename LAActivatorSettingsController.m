#import "libactivator.h"
#import "libactivator-private.h"
#import "ActivatorEventViewHeader.h"

// LASettingsViewController

@implementation LASettingsViewController

+ (id)controller
{
	return [[[self alloc] init] autorelease];
}

- (id)init
{
	return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc
{
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	[super dealloc];
}

@synthesize tableView = _tableView, delegate = _delegate;

- (void)loadView
{
	if (!_tableView) {
		_tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		_tableView.rowHeight = 60.0f;
		_tableView.delegate = self;
		_tableView.dataSource = self;
	}
	self.view = _tableView;
}

- (void)viewDidUnload
{
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	_tableView = nil;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushSettingsController:(LASettingsViewController *)controller
{
	if (_delegate) {
		controller.delegate = _delegate;
		[_delegate settingsViewController:self shouldPushToChildController:controller];
	} else {
		[self.navigationController pushViewController:controller animated:YES];
	}
}

@end

// LAEventSettingsController

@interface LAEventSettingsController () <ActivatorEventViewHeaderDelegate>
@end

@implementation LAEventSettingsController

- (void)updateHeader
{
	_headerView.listenerName = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:[_modes objectAtIndex:0]]];
	UITableView *tableView = self.tableView;
	CGRect frame = _headerView.frame;
	frame.size.width = tableView.bounds.size.width;
	_headerView.frame = frame;
	tableView.tableHeaderView = _headerView;
}

- (id)initWithModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super init])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		_listeners = [[LASharedActivator _cachedAndSortedListeners] mutableCopy];
		for (NSString *key in [_listeners allKeys]) {
			NSArray *group = [_listeners objectForKey:key];
			NSMutableArray *mutableGroup = [NSMutableArray array];
			BOOL hasItems = NO;
			for (NSString *listenerName in group) {
				if ([LASharedActivator listenerWithName:listenerName isCompatibleWithEventName:eventName])
					for (NSString *mode in _modes)
						if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode]) {
							[mutableGroup addObject:listenerName];
							hasItems = YES;
							break;
						}
			}
			if (hasItems)
				[_listeners setObject:mutableGroup forKey:key];
			else
				[_listeners removeObjectForKey:key];
		}
		_groups = [[[_listeners allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
		_eventName = [eventName copy];
		self.navigationItem.title = [LASharedActivator localizedTitleForEventName:_eventName];
		CGRect headerFrame;
		headerFrame.origin.x = 0.0f;
		headerFrame.origin.y = 0.0f;
		headerFrame.size.width = 0.0f;
		headerFrame.size.height = 76.0f;
		_headerView = [[ActivatorEventViewHeader alloc] initWithFrame:headerFrame];
		_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_headerView.delegate = self;
		[self updateHeader];
	}
	return self;
}

- (void)dealloc
{
	_headerView.delegate = nil;
	[_headerView release];
	[_groups release];
	[_listeners release];
	[_eventName release];
	[_modes release];
	[super dealloc];
}

- (void)viewDidLoad
{
	[self updateHeader];
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSString *title = [LASharedActivator localizedStringForKey:@"CANT_DEACTIVATE_REMAINING" value:@"Can't deactivate\nremaining event"];
	NSString *message = [NSString stringWithFormat:[LASharedActivator localizedStringForKey:@"AT_LEAST_ONE_ASSIGNMENT_REQUIRED" value:@"At least one event must be\nassigned to %@"], [LASharedActivator localizedTitleForListenerName:listenerName]];
	NSString *cancelButtonTitle = [LASharedActivator localizedStringForKey:@"ALERT_OK" value:@"OK"];
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	[av show];
	[av release];
}

- (BOOL)allowedToUnassignEventsFromListener:(NSString *)listenerName
{
	if (![LASharedActivator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[LASharedActivator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in _modes)
		if ([[LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;
}

- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader
{
	NSMutableArray *events = [NSMutableArray array];
	for (NSString *mode in _modes) {
		LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
		NSString *listenerName = [LASharedActivator assignedListenerNameForEvent:event];
		if (listenerName) {
			if (![self allowedToUnassignEventsFromListener:listenerName]) {
				[self showLastEventMessageForListener:listenerName];
				return;
			}
			[events addObject:event];
		}
	}
	for (LAEvent *event in events)
		[LASharedActivator unassignEvent:event];
	eventViewHeader.listenerName = nil;
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_listeners objectForKey:[_groups objectAtIndex:index]];
}

- (NSString *)listenerNameForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [_groups count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_groups objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [[self groupAtIndex:section] count];
}

- (NSInteger)countOfModesAssignedToListener:(NSString *)name
{
	NSInteger result = 0;
	for (NSString *mode in _modes) {
		NSString *assignedName = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		result += [assignedName isEqual:name];
	}
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	cell.textLabel.text = [LASharedActivator localizedTitleForListenerName:listenerName];
	UITableViewCellAccessoryType accessory = 
		[self countOfModesAssignedToListener:listenerName] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone;
	cell.detailTextLabel.text = [LASharedActivator localizedDescriptionForListenerName:listenerName];
	cell.imageView.image = [LASharedActivator smallIconForListenerName:listenerName];
	cell.accessoryType = accessory;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	NSUInteger compatibleModeCount = 0;
	for (NSString *mode in _modes)
		if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode])
			compatibleModeCount++;
	BOOL allAssigned = [self countOfModesAssignedToListener:listenerName] >= compatibleModeCount;
	if (allAssigned) {
		if (![self allowedToUnassignEventsFromListener:listenerName]) {
			[self showLastEventMessageForListener:listenerName];
			return;
		}
		cell.accessoryType = UITableViewCellAccessoryNone;
		for (NSString *mode in _modes)
			[LASharedActivator unassignEvent:[LAEvent eventWithName:_eventName mode:mode]];
	} else {
		for (NSString *mode in _modes) {
			NSString *otherListener = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:listenerName]) {
				if (![self allowedToUnassignEventsFromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					return;
				}
			}
		}
		for (UITableViewCell *otherCell in [tableView visibleCells])
			otherCell.accessoryType = UITableViewCellAccessoryNone;
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		for (NSString *mode in _modes) {
			LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
			if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode])
				[LASharedActivator assignEvent:event toListenerWithName:listenerName];
			else
				[LASharedActivator unassignEvent:event];
		}
	}
	[self updateHeader];
}

@end

// LAEventGroupSettingsController

@interface LAEventGroupSettingsController : LASettingsViewController {
@private
	NSArray *_modes;
	NSArray *_events;
	NSString *_groupName;
}
@end

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

// LAModeSettingsController

NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[LASharedActivator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[LASharedActivator localizedTitleForEventName:b]];
}

@implementation LAModeSettingsController

- (id)initWithMode:(NSString *)mode
{
	if ((self = [super init])) {
		_eventMode = [mode copy];
		self.navigationItem.title = [LASharedActivator localizedTitleForEventMode:_eventMode];
		BOOL showHidden = [[LASharedActivator _getObjectForPreference:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
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
		NSArray *groupNames = [_events allKeys];
		for (NSString *key in groupNames)
			[[_events objectForKey:key] sortUsingFunction:CompareEventNamesCallback context:nil];
		_groups = [[groupNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] retain];
	}
	return self;
}

- (void)dealloc
{
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
	return [[self groupAtIndex:index] count] > 7;
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
		alpha = [LASharedActivator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	}
	label.alpha = alpha;
	detailLabel.alpha = alpha;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	LASettingsViewController *vc;
	NSArray *modes = _eventMode ? [NSArray arrayWithObject:_eventMode] : [LASharedActivator availableEventModes];
	if ([self groupAtIndexIsLarge:indexPath.section])
		vc = [[LAEventGroupSettingsController alloc] initWithModes:modes events:[self groupAtIndex:indexPath.section] groupName:[_groups objectAtIndex:indexPath.section]];
	else
		vc = [[LAEventSettingsController alloc] initWithModes:modes eventName:[self eventNameForIndexPath:indexPath]];
	[self pushSettingsController:vc];
	[vc release];
}

@end

// LAWebSettingsController

__attribute__((visibility("hidden")))
@interface LAWebSettingsController : LARootSettingsController<UIWebViewDelegate> {
@private
	UIView *_backgroundView;
	UIActivityIndicatorView *_activityView;
	UIWebView *_webView;
}

@end

@implementation LAWebSettingsController

- (id)init
{
	if ((self = [super init])) {
		_backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		[_backgroundView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
		_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
		[_webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[_webView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
		[[_webView _scroller] setShowBackgroundShadow:NO];
		[_webView setDelegate:self];
		[_webView setHidden:YES];
		[_backgroundView addSubview:_webView];
		_activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		CGRect frame;
		frame.size = [_activityView frame].size;
		frame.origin.x = (NSInteger)frame.size.width / -2;
		frame.origin.y = (NSInteger)frame.size.height / -2;
		[_activityView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
		[_activityView setFrame:frame];
		[_activityView startAnimating];
		[_backgroundView addSubview:_activityView];
		frame.size.width = 100.0f;
		frame.size.height = 100.0f;
		_backgroundView.frame = frame;
	}
	return self;
}

- (void)loadView
{
	self.view = _backgroundView;
}

- (void)loadURL:(NSURL *)url
{
	[_webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)dealloc
{
	[_webView setDelegate:nil];
	[_webView release];
	[_activityView stopAnimating];
	[_activityView release];
	[_backgroundView release];
	[super dealloc];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	NSString *urlString = [url absoluteString];
	if ([urlString isEqualToString:@"about:Blank"])
		return YES;
	if ([urlString hasPrefix:@"http://rpetri.ch/"])
		return YES;
	[[UIApplication sharedApplication] openURL:url];
	return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[_activityView stopAnimating];
	[_activityView setHidden:YES];
	[_webView setHidden:NO];
}

@end

// LARootSettingsController

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
			return 1;
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
			return @"\u00A9 2009-2010 Ryan Petrich";
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
			cell.textLabel.text = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"];
			cell.detailTextLabel.text = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS_DETAIL" value:@"Get more actions via Cydia"];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
		case 2: {
			LAWebSettingsController *wsc = [LAWebSettingsController controller];
			[wsc loadURL:[NSURL URLWithString:kWebURL]];
			wsc.navigationItem.title = [LASharedActivator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"];
			vc = wsc;
			break;
		}
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
