#import "libactivator-private.h"
#import "ActivatorEventViewHeader.h"
#import "LAListenerTableViewDataSource.h"

@interface LAEventSettingsController () <ActivatorEventViewHeaderDelegate, LAListenerTableViewDataSourceDelegate, UISearchBarDelegate>
@end

@implementation LAEventSettingsController

- (void)updateHeader
{
	[_currentAssignments removeAllObjects];
	for (NSString *mode in _modes) {
		NSString *assigned = [LASharedActivator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		if (assigned)
			[_currentAssignments addObject:assigned];
	}
	_headerView.listenerNames = _currentAssignments;
	UITableView *tableView = self.tableView;
	CGRect frame = _headerView.frame;
	frame.size.width = tableView.bounds.size.width;
	_headerView.frame = frame;
	tableView.tableHeaderView = [_searchBar isFirstResponder] ? nil : _headerView;
}

- (id)initWithModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super init])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([LASharedActivator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		_currentAssignments = [[NSMutableSet alloc] init];
		_eventName = [eventName copy];
		_dataSource = [[LAListenerTableViewDataSource alloc] init];
		_dataSource.delegate = self;
		self.navigationItem.title = [LASharedActivator localizedTitleForEventName:_eventName];
		CGRect headerFrame;
		headerFrame.origin.x = 0.0f;
		headerFrame.origin.y = 0.0f;
		headerFrame.size.width = 0.0f;
		headerFrame.size.height = 76.0f;
		_headerView = [[ActivatorEventViewHeader alloc] initWithFrame:headerFrame];
		_headerView.delegate = self;
		[self updateHeader];
		_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
		_searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		if ([_searchBar respondsToSelector:@selector(setUsesEmbeddedAppearance:)])
			[_searchBar setUsesEmbeddedAppearance:YES];
		_searchBar.delegate = self;
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(keyboardWillShowWithNotification:) name:UIKeyboardWillShowNotification object:nil];
		[nc addObserver:self selector:@selector(keyboardWillHideWithNotification:) name:UIKeyboardWillHideNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_searchBar.delegate = nil;
	_headerView.delegate = nil;
	[_searchBar release];
	[_headerView release];
	[_dataSource release];
	[_eventName release];
	[_currentAssignments release];
	[_modes release];
	[super dealloc];
}

- (void)keyboardWillShowWithNotification:(NSNotification *)notification
{
	[UIView beginAnimations:nil context:NULL];
	NSDictionary *userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
	CGRect keyboardFrame = CGRectZero;
    [[userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardFrame];
    UIEdgeInsets insets;
    insets.top = 44.0f;
    insets.right = 0.0f;
    insets.bottom = keyboardFrame.size.height;
    insets.left = 0.0f;
    UITableView *tableView = self.tableView;
    tableView.contentInset = insets;
    insets.top = 0.0f;
    tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];
}

- (void)keyboardWillHideWithNotification:(NSNotification *)notification
{
	[UIView beginAnimations:nil context:NULL];
	NSDictionary *userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    UIEdgeInsets insets;
    insets.top = 44.0f;
    insets.right = 0.0f;
    insets.bottom = 0.0f;
    insets.left = 0.0f;
    UITableView *tableView = self.tableView;
    tableView.contentInset = insets;
    insets.top = 0.0f;
    tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
	[_searchBar setShowsCancelButton:YES animated:YES];
	[self updateHeader];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
	[_searchBar setShowsCancelButton:NO animated:YES];
	[self updateHeader];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	_dataSource.searchText = searchText;
	UITableView *tableView = self.tableView;
	[tableView reloadData];
	tableView.contentOffset = CGPointMake(0.0f, -44.0f);
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
	searchBar.text = nil;
	_dataSource.searchText = nil;
	[self.tableView reloadData];
	[searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
}

- (BOOL)dataSource:(LAListenerTableViewDataSource *)dataSource shouldAllowListenerWithName:(NSString *)listenerName
{
	if ([LASharedActivator listenerWithName:listenerName isCompatibleWithEventName:_eventName])
		for (NSString *mode in _modes)
			if ([LASharedActivator listenerWithName:listenerName isCompatibleWithMode:mode])
				return YES;
	return NO;
}

- (void)loadView
{
	[super loadView];
	self.tableView.dataSource = _dataSource;
}

- (void)viewDidLoad
{
    UIEdgeInsets insets;
    insets.top = 44.0f;
    insets.right = 0.0f;
    insets.bottom = 0.0f;
    insets.left = 0.0f;
    UITableView *tableView = self.tableView;
    tableView.contentInset = insets;
    insets.top = 0.0f;
    tableView.scrollIndicatorInsets = insets;
    CGRect frame;
    frame.origin.x = 0.0f;
    frame.origin.y = -44.0f;
    frame.size.height = 44.0f;
    frame.size.width = tableView.bounds.size.width;
    _searchBar.frame = frame;
	[tableView addSubview:_searchBar];
	[self updateHeader];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_searchBar resignFirstResponder];
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
	for (UITableViewCell *cell in [[self tableView] visibleCells])
		cell.accessoryType = UITableViewCellAccessoryNone;
	eventViewHeader.listenerNames = nil;
	[self updateHeader];
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

- (void)dataSource:(LAListenerTableViewDataSource *)dataSource appliedContentToCell:(UITableViewCell *)cell forListenerWithName:(NSString *)listenerName
{
	BOOL assigned = [_currentAssignments containsObject:listenerName];
	cell.accessoryType = assigned ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [_dataSource listenerNameForRowAtIndexPath:indexPath];
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
