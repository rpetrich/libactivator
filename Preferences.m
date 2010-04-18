#import <Preferences/Preferences.h>
#import <QuartzCore/QuartzCore.h>

#import "libactivator.h"
#import "libactivator-private.h"
#import "ActivatorAdController.h"

// TODO: figure out the proper way to store this in headers
@interface PSViewController (OS32)
@property (nonatomic, retain) PSSpecifier *specifier;
@end

static LAActivator *activator;

#define kWebURL [NSString stringWithFormat:@"http://rpetri.ch/cydia/activator/actions/?udid=", [[UIDevice currentDevice] uniqueIdentifier]]

@interface ActivatorSettingsViewController : PSViewController {
@private
	NSString *_navigationTitle;
}
- (id)initForContentSize:(CGSize)size;
- (void)loadFromSpecifier:(PSSpecifier *)specifier;
@property (nonatomic, copy) NSString *navigationTitle;
@end

@implementation ActivatorSettingsViewController

- (id)initForContentSize:(CGSize)size
{
	if ([[PSViewController class] instancesRespondToSelector:@selector(initForContentSize:)])
		return [super initForContentSize:size];
	else
		return [super init];
}

- (void)dealloc
{
	[_navigationTitle release];
	[super dealloc];
}

- (NSString *)navigationTitle
{
	return [[_navigationTitle retain] autorelease];
}

- (void)setNavigationTitle:(NSString *)navigationTitle
{
	[_navigationTitle autorelease];
	_navigationTitle = [navigationTitle retain];
	if ([self respondsToSelector:@selector(navigationItem)])
		[[self navigationItem] setTitle:_navigationTitle];
}

- (void)setSpecifier:(PSSpecifier *)specifier
{
	[self loadFromSpecifier:specifier];
	[super setSpecifier:specifier];
}

- (void)viewWillBecomeVisible:(void *)source
{
	if (source)
		[self loadFromSpecifier:(PSSpecifier *)source];
	[super viewWillBecomeVisible:source];
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier
{
}

@end

@interface ActivatorWebViewController : ActivatorSettingsViewController<UIWebViewDelegate> {
@private
	UIView *_backgroundView;
	UIActivityIndicatorView *_activityView;
	UIWebView *_webView;
}

@end

@implementation ActivatorWebViewController

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		CGRect frame;
		frame.origin = CGPointZero;
		frame.size = size;
		_backgroundView = [[UIView alloc] initWithFrame:frame];
		[_backgroundView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
		[_backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		_webView = [[UIWebView alloc] initWithFrame:frame];
		[_webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[_webView setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
		[[_webView _scroller] setShowBackgroundShadow:NO];
		[_webView setDelegate:self];
		[_webView setHidden:YES];
		[_backgroundView addSubview:_webView];
		_activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		frame.size = [_activityView frame].size;
		frame.origin.x = (NSInteger)(size.width - frame.size.width) / 2;
		frame.origin.y = (NSInteger)(size.height - frame.size.height) / 2;
		[_activityView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
		[_activityView setFrame:frame];
		[_activityView startAnimating];
		[_backgroundView addSubview:_activityView];
	}
	return self;
}

- (id)initForContentSize:(CGSize)size withURL:(NSURL *)url
{
	if ((self = [self initForContentSize:size])) {
		[_webView loadRequest:[NSURLRequest requestWithURL:url]];
	}
	return self;
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

- (UIView *)view
{
	return _backgroundView;
}

- (UIWebView *)webView
{
	return _webView;
}

- (CGSize)contentSize
{
	return [_backgroundView frame].size;
}

- (void)pushController:(id<PSBaseView>)controller
{
	[super pushController:controller];
	[controller setParentController:self];
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

@interface ActivatorTableViewController : ActivatorSettingsViewController<UITableViewDataSource, UITableViewDelegate> {
@private
	UITableView *_tableView;
}

@end

@implementation ActivatorTableViewController

+ (void)load
{
	activator = [LAActivator sharedInstance];
}

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		CGRect frame;
		frame.origin = CGPointZero;
		frame.size = size;
		_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
		[_tableView setRowHeight:60.0f];
		[_tableView setDataSource:self];
		[_tableView setDelegate:self];
		[_tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	}
	return self;
}

- (void)dealloc
{
	[_tableView setDelegate:nil];
	[_tableView setDataSource:nil];
	[_tableView release];
	[super dealloc];
}

- (UIView *)view
{
	return _tableView;
}

- (UITableView *)tableView
{
	return _tableView;
}

- (CGSize)contentSize
{
	return [_tableView frame].size;
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

- (void)pushController:(id<PSBaseView>)controller
{
	//[[self parentController] pushController:controller];
	[super pushController:controller];
	[controller setParentController:self];
}

@end

@protocol ActivatorEventViewHeaderDelegate;

@interface ActivatorEventViewHeader : UIView {
@private
	NSString *_listenerName;
	id<ActivatorEventViewHeaderDelegate> _delegate;
}

@property (nonatomic, copy) NSString *listenerName;
@property (nonatomic, assign) id<ActivatorEventViewHeaderDelegate> delegate;

@end

@protocol ActivatorEventViewHeaderDelegate <NSObject>
@required
- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader;
@end


@implementation ActivatorEventViewHeader

@synthesize delegate = _delegate;

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setOpaque:YES];
		[self setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	}
	return self;
}

- (NSString *)listenerName
{
	return _listenerName;
}

- (void)setListenerName:(NSString *)listenerName
{
	if (![_listenerName isEqualToString:listenerName]) {
		[_listenerName release];
		_listenerName = [listenerName copy];
		[self setNeedsDisplay];
		CATransition *animation = [CATransition animation];
		[animation setType:kCATransitionFade];
		//[animation setDuration:0.3];
		[[self layer] addAnimation:animation forKey:kCATransition];
	}
}

- (void)drawRect:(CGRect)rect
{
	[[UIColor tableSeparatorDarkColor] setFill];
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextSetShadowWithColor(c, CGSizeMake(0.0f, -1.0f), 0.0f, [[UIColor tableSeparatorLightColor] CGColor]);
	CGRect line = [self bounds];
	line.origin.x = 15.0f;
	line.size.width -= 30.0f;
	line.origin.y = line.size.height - 2.0f;
	line.size.height = 1.0f;
	UIRectFill(line);
	[[UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f] setFill];
	CGContextSetShadowWithColor(c, CGSizeMake(0.0f, -1.0f), 0.0f, [[UIColor whiteColor] CGColor]);
	[[activator localizedStringForKey:@"CURRENTLY_ASSIGNED_TO" value:@"Currently assigned to:"] drawAtPoint:CGPointMake(20.0f, 9.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	if ([_listenerName length]) {
		// Draw Close Button
		CGContextBeginPath(c);
		CGRect closeRect;
		closeRect.origin.x = line.size.width - 5;
		closeRect.origin.y = 40.0f;
		closeRect.size.width = 20.0f;
		closeRect.size.height = 20.0f;
		CGContextAddEllipseInRect(c, closeRect);
		const CGFloat lineWidth = 1.25f;
		const CGPoint points[] = {
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4) + lineWidth, closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 2), closeRect.origin.y + (closeRect.size.height / 2) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4) - lineWidth, closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height / 4) + lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 2) + lineWidth, closeRect.origin.y + (closeRect.size.height / 2) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4) - lineWidth, closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 2), closeRect.origin.y + (closeRect.size.height / 2) + lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 4) + lineWidth, closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 2) - lineWidth, closeRect.origin.y + (closeRect.size.height / 2) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height / 4) + lineWidth }
		};
		CGContextAddLines(c, points, 16);
		CGContextClosePath(c);
		CGContextEOFillPath(c);
		// Draw Image
		UIImage *image = [activator smallIconForListenerName:_listenerName];
		CGFloat x;
		if (image) {
			[image drawAtPoint:CGPointMake(20.0f, 35.0f)];
			x = 30.0f + [image size].width;
		} else {
			x = 30.0f;
		}
		// Draw Text
		[[UIColor blackColor] setFill];
		[[activator localizedTitleForListenerName:_listenerName] drawAtPoint:CGPointMake(x, 39.0f) withFont:[UIFont boldSystemFontOfSize:19.0f]];
	} else {
		[[activator localizedStringForKey:@"UNASSIGNED" value:@"(unassigned)"] drawAtPoint:CGPointMake(30.0f, 40.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	[_delegate eventViewHeaderCloseButtonTapped:self];
}

@end

@interface ActivatorEventViewController : ActivatorTableViewController<ActivatorEventViewHeaderDelegate> {
@private
	NSArray *_modes;
	NSString *_eventName;
	NSMutableDictionary *_listeners;
	NSArray *_groups;
	ActivatorEventViewHeader *_headerView;
}
@end

@implementation ActivatorEventViewController

- (void)updateHeader
{
	[_headerView setListenerName:[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:[_modes objectAtIndex:0]]]];
	[[self tableView] setTableHeaderView:_headerView];
}

- (id)initForContentSize:(CGSize)contentSize withModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super initForContentSize:contentSize])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([activator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		_listeners = [[activator _cachedAndSortedListeners] mutableCopy];
		for (NSString *key in [_listeners allKeys]) {
			NSArray *group = [_listeners objectForKey:key];
			NSMutableArray *mutableGroup = [NSMutableArray array];
			BOOL hasItems = NO;
			for (NSString *listenerName in group) {
				if ([activator listenerWithName:listenerName isCompatibleWithEventName:eventName])
					for (NSString *mode in _modes)
						if ([activator listenerWithName:listenerName isCompatibleWithMode:mode]) {
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
		[self setNavigationTitle:[activator localizedTitleForEventName:_eventName]];
		CGRect headerFrame;
		headerFrame.origin.x = 0.0f;
		headerFrame.origin.y = 0.0f;
		headerFrame.size.width = contentSize.width;
		headerFrame.size.height = 76.0f;
		_headerView = [[ActivatorEventViewHeader alloc] initWithFrame:headerFrame];
		[_headerView setDelegate:self];
		[self updateHeader];
	}
	return self;
}

- (void)dealloc
{
	[_headerView setDelegate:nil];
	[_headerView release];
	[_groups release];
	[_listeners release];
	[_eventName release];
	[_modes release];
	[super dealloc];
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	NSString *title = [activator localizedStringForKey:@"CANT_DEACTIVATE_REMAINING" value:@"Can't deactivate\nremaining event"];
	NSString *message = [NSString stringWithFormat:[activator localizedStringForKey:@"AT_LEAST_ONE_ASSIGNMENT_REQUIRED" value:@"At least one event must be\nassigned to %@"], [activator localizedTitleForListenerName:listenerName]];
	NSString *cancelButtonTitle = [activator localizedStringForKey:@"ALERT_OK" value:@"OK"];
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
	[av show];
	[av release];
}

- (BOOL)allowedToUnassignEventsFromListener:(NSString *)listenerName
{
	if (![activator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[activator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in _modes)
		if ([[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;
}

- (void)eventViewHeaderCloseButtonTapped:(ActivatorEventViewHeader *)eventViewHeader
{
	NSMutableArray *events = [NSMutableArray array];
	for (NSString *mode in _modes) {
		LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
		NSString *listenerName = [activator assignedListenerNameForEvent:event];
		if (listenerName) {
			if (![self allowedToUnassignEventsFromListener:listenerName]) {
				[self showLastEventMessageForListener:listenerName];
				return;
			}
			[events addObject:event];
		}
	}
	for (LAEvent *event in events)
		[activator unassignEvent:event];
	[eventViewHeader setListenerName:nil];
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
		NSString *assignedName = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		result += [assignedName isEqual:name];
	}
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	[[cell textLabel] setText:[activator localizedTitleForListenerName:listenerName]];
	UITableViewCellAccessoryType accessory = 
		[self countOfModesAssignedToListener:listenerName] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone;
	[[cell detailTextLabel] setText:[activator localizedDescriptionForListenerName:listenerName]];
	[[cell imageView] setImage:[activator smallIconForListenerName:listenerName]];
	[cell setAccessoryType:accessory];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [self listenerNameForRowAtIndexPath:indexPath];
	NSUInteger compatibleModeCount = 0;
	for (NSString *mode in _modes)
		if ([activator listenerWithName:listenerName isCompatibleWithMode:mode])
			compatibleModeCount++;
	BOOL allAssigned = [self countOfModesAssignedToListener:listenerName] >= compatibleModeCount;
	if (allAssigned) {
		if (![self allowedToUnassignEventsFromListener:listenerName]) {
			[self showLastEventMessageForListener:listenerName];
			return;
		}
		[cell setAccessoryType:UITableViewCellAccessoryNone];
		for (NSString *mode in _modes)
			[activator unassignEvent:[LAEvent eventWithName:_eventName mode:mode]];
	} else {
		for (NSString *mode in _modes) {
			NSString *otherListener = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:listenerName]) {
				if (![self allowedToUnassignEventsFromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					return;
				}
			}
		}
		for (UITableViewCell *otherCell in [tableView visibleCells])
			[otherCell setAccessoryType:UITableViewCellAccessoryNone];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
		for (NSString *mode in _modes) {
			LAEvent *event = [LAEvent eventWithName:_eventName mode:mode];
			if ([activator listenerWithName:listenerName isCompatibleWithMode:mode])
				[activator assignEvent:event toListenerWithName:listenerName];
			else
				[activator unassignEvent:event];
		}
	}
	[self updateHeader];
}

@end

@interface ActivatorEventGroupViewController : ActivatorTableViewController {
@private
	NSArray *_modes;
	NSArray *_events;
	NSString *_groupName;
}
@end

@implementation ActivatorEventGroupViewController
- (id)initForContentSize:(CGSize)contentSize withModes:(NSArray *)modes events:(NSMutableArray *)events groupName:(NSString *)groupName
{
	if ((self = [super initForContentSize:contentSize])) {
		_modes = [modes copy];
		_events = [events copy];
		_groupName = [groupName copy];
		[self setNavigationTitle:_groupName];
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
	CGFloat alpha = [activator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = [cell textLabel];
	[label setText:[activator localizedTitleForEventName:eventName]];
	[label setAlpha:alpha];
	UILabel *detailLabel = [cell detailTextLabel];
	[detailLabel setText:[activator localizedDescriptionForEventName:eventName]];
	[detailLabel setAlpha:alpha];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	PSViewController *vc = [[ActivatorEventViewController alloc] initForContentSize:[self contentSize] withModes:_modes eventName:[_events objectAtIndex:indexPath.row]];
	[self pushController:vc];
	[vc release];
}

@end


@interface ActivatorModeViewController : ActivatorTableViewController {
@private
	NSString *_eventMode;
	NSMutableDictionary *_events;
	NSArray *_groups;
}
@end

NSInteger CompareEventNamesCallback(id a, id b, void *context)
{
	return [[activator localizedTitleForEventName:a] localizedCaseInsensitiveCompare:[activator localizedTitleForEventName:b]];
}

@implementation ActivatorModeViewController

- (id)initForContentSize:(CGSize)contentSize withMode:(NSString *)mode
{
	if ((self = [super initForContentSize:contentSize])) {
		_eventMode = [mode copy];
		[self setNavigationTitle:[activator localizedTitleForEventMode:_eventMode]];
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:[activator settingsFilePath]] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		for (NSString *eventName in [activator availableEventNames]) {
			if ([activator eventWithName:eventName isCompatibleWithMode:mode]) {
				if (!([activator eventWithNameIsHidden:eventName] || showHidden)) {
					NSString *key = [activator localizedGroupForEventName:eventName] ?: @"";
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
		[label setText:[_groups objectAtIndex:section]];
		NSString *template = [activator localizedStringForKey:@"N_ADDITIONAL_EVENTS" value:@"%i additional events"];
		[detailLabel setText:[NSString stringWithFormat:template, [[self groupAtIndex:section] count]]];
		alpha = 1.0f;		
	} else {
		NSString *eventName = [self eventNameForIndexPath:indexPath];
		[label setText:[activator localizedTitleForEventName:eventName]];
		[detailLabel setText:[activator localizedDescriptionForEventName:eventName]];
		alpha = [activator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	}
	[label setAlpha:alpha];
	[detailLabel setAlpha:alpha];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	PSViewController *vc;
	CGSize contentSize = [self contentSize];
	NSArray *modes = _eventMode ? [NSArray arrayWithObject:_eventMode] : [activator availableEventModes];
	if ([self groupAtIndexIsLarge:indexPath.section])
		vc = [[ActivatorEventGroupViewController alloc] initForContentSize:contentSize withModes:modes events:[self groupAtIndex:indexPath.section] groupName:[_groups objectAtIndex:indexPath.section]];
	else
		vc = [[ActivatorEventViewController alloc] initForContentSize:contentSize withModes:modes eventName:[self eventNameForIndexPath:indexPath]];
	[self pushController:vc];
	[vc release];
}

@end

@interface ActivatorSettingsController : ActivatorTableViewController {
@private
	LAListenerSettingsViewController *_viewController;
	CGSize _size;
}
- (void)resetTitle;
@end

@implementation ActivatorSettingsController

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		[self resetTitle];
	}
	return self;
}

- (void)dealloc
{
	[_viewController release];
	[super dealloc];
}

- (void)resetTitle
{
	[self setNavigationTitle:[activator localizedStringForKey:@"ACTIVATOR" value:@"Activator"]];
}

- (void)loadFromSpecifier:(PSSpecifier *)specifier
{
	// Load LAListenerSettingsViewController if activatorListener is set in the specifier
	[_viewController release];
	_viewController = nil;
	NSString *listenerName = [specifier propertyForKey:@"activatorListener"];
	if ([listenerName length]) {
		NSLog(@"libactivator: Configuring %@", listenerName);
		_viewController = [[LAListenerSettingsViewController alloc] init];
		[_viewController setListenerName:listenerName];
		NSString *title = [[specifier propertyForKey:@"activatorTitle"]?:[specifier name] copy];
		if ([title length]) {
			[self setNavigationTitle:title];
			return;
		}
	}
	[self resetTitle];
}

- (void)viewDidBecomeVisible
{
	[super viewDidBecomeVisible];
	if (!_viewController && [[activator _getObjectForPreference:@"LAHideAds"] boolValue] == NO) {
		ActivatorAdController *aac = [ActivatorAdController sharedInstance];
		[aac setURL:kWebURL];
		[aac displayOnTarget:[[self view] superview]];
	}
}

- (BOOL)popControllerWithAnimation:(BOOL)animation
{
	[[ActivatorAdController sharedInstance] hideAnimated:YES];
	return [super popControllerWithAnimation:animation];
}

- (UIView *)view
{
	// Swap out for view controller if set
	UIView *view = [super view];
	if (_viewController) {
		UIView *replacement = [_viewController view];
		[replacement setFrame:[view frame]];
		view = replacement;
	}
	return view;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return 1;
		case 1:
			return [[activator availableEventModes] count];
		case 2:
			return 1;
		default:
			return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section) {
		case 2:
			return [activator localizedStringForKey:@"LOCALIZATION_ABOUT" value:@""];
		case 3:
			return @"\u00A9 2009-2010 Ryan Petrich";
		default:
			return nil;
	}
}

- (NSString *)eventModeForIndexPath:(NSIndexPath *)indexPath
{
	switch ([indexPath section]) {
		case 1:
			return [[activator availableEventModes] objectAtIndex:[indexPath row]];
		default:
			return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	if (indexPath.section != 2) {
		NSString *eventMode = [self eventModeForIndexPath:indexPath];
		[[cell textLabel] setText:[activator localizedTitleForEventMode:eventMode]];
		[[cell detailTextLabel] setText:[activator localizedDescriptionForEventMode:eventMode]];
	} else {
		[[cell textLabel] setText:[activator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"]];
		[[cell detailTextLabel] setText:[activator localizedStringForKey:@"MORE_ACTIONS_DETAIL" value:@"Get more actions via Cydia"]];
	}
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	PSViewController *vc;
	if (indexPath.section != 2)
		vc = [[ActivatorModeViewController alloc] initForContentSize:[self contentSize] withMode:[self eventModeForIndexPath:indexPath]];
	else {
		ActivatorWebViewController *wvc = [[ActivatorWebViewController alloc] initForContentSize:[self contentSize] withURL:[NSURL URLWithString:kWebURL]];
		[wvc setNavigationTitle:[activator localizedStringForKey:@"MORE_ACTIONS" value:@"More Actions"]];
		vc = wvc;
	}
	[self pushController:vc];
	[vc release];
}

@end
