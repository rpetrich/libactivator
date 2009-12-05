#import <Foundation/Foundation.h>
#import <Preferences/Preferences.h>
#import <notify.h>

#define kPreferencesFilePath @"/User/Library/Preferences/libactivator.plist"

@interface ActivatorSettingsController : PSViewController<UITableViewDelegate, UITableViewDataSource> {
	UITableView *_tableView;
	NSString *_listenerName;
	NSString *_title;
	NSArray *_events;
	NSMutableDictionary *_eventData;
	NSMutableDictionary *_preferences;
}
@end

static NSInteger ActivatorSettingsSortFunction(id a, id b, void *context)
{
	NSDictionary *eventData = (NSDictionary *)context;
	NSDictionary *aData = [eventData objectForKey:a];
	NSDictionary *bData = [eventData objectForKey:b];
	NSInteger aIndex = [[aData objectForKey:@"index"] integerValue];
	NSInteger bIndex = [[bData objectForKey:@"index"] integerValue];
	if (aIndex < bIndex)
		return NSOrderedAscending;
	if (aIndex > bIndex)
		return NSOrderedDescending;
	NSString *aTitle = [aData objectForKey:@"title"];
	NSString *bTitle = [bData objectForKey:@"title"];
	return [aTitle caseInsensitiveCompare:bTitle];
}

@implementation ActivatorSettingsController

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		_preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:kPreferencesFilePath];
		if (!_preferences)
			_preferences = [[NSMutableDictionary alloc] init];
		NSMutableArray *events = [[NSMutableArray alloc] init];
		_eventData = [[NSMutableDictionary alloc] init];
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Activator/Events" error:NULL]) {
			if (![fileName hasPrefix:@"."]) {
				[events addObject:fileName];
				NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/Library/Activator/Events/%@/Info.plist", fileName]];
				[_eventData setObject:infoDict forKey:fileName];
				[infoDict release];
			}
		}
		_events = [[events sortedArrayUsingFunction:ActivatorSettingsSortFunction context:_eventData] retain];
		[events release];
		CGRect frame;
		frame.origin = CGPointZero;
		frame.size = size;
		_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
		[_tableView setDelegate:self];
		[_tableView setDataSource:self];
	}
	return self;
}

- (void)dealloc
{
	[_tableView setDataSource:nil];
	[_tableView setDelegate:nil];
	[_tableView release];
	[_preferences release];
	[_listenerName release];
	[_title release];
	[_eventData release];
	[_events release];
	[super dealloc];
}

- (void)viewWillBecomeVisible:(void *)source
{
	PSSpecifier *specifier = (PSSpecifier *)source;
	[_listenerName release];
	_listenerName = [[specifier propertyForKey:@"activatorListener"] copy];
	[_title release];
	_title = [specifier propertyForKey:@"activatorTitle"];
	if (_title)
		_title = [_title retain];
	else
		_title = [[specifier propertyForKey:@"label"] copy];
	[super viewWillBecomeVisible:source];
}

- (NSString *)navigationTitle
{
	if ([_title length])
		return _title;
	else
		return _listenerName;
}

- (UIView *)view
{
	return _tableView;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [_events count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (cell == nil)
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"Cell"] autorelease];
	NSInteger row = [indexPath row];
	NSString *eventName = [_events objectAtIndex:row];
	id preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
	UITableViewCellAccessoryType accessory;
	if ([[_preferences objectForKey:preferenceName] isEqualToString:_listenerName])
		accessory = UITableViewCellAccessoryCheckmark;
	else
		accessory = UITableViewCellAccessoryNone;
	[cell setAccessoryType:accessory];
	NSString *eventTitle = [[_eventData objectForKey:eventName] objectForKey:@"title"];
	[cell setText:eventTitle];
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UITableViewCellAccessoryType accessory = [cell accessoryType];
	NSInteger row = [indexPath row];
	NSString *eventName = [_events objectAtIndex:row];
	id preferenceName = [@"LAEventListener-" stringByAppendingString:eventName];
	if (accessory == UITableViewCellAccessoryNone) {
		accessory = UITableViewCellAccessoryCheckmark;
		[_preferences setObject:_listenerName forKey:preferenceName];
	} else {
		accessory = UITableViewCellAccessoryNone;
		[_preferences removeObjectForKey:preferenceName];
	}
	[_preferences writeToFile:kPreferencesFilePath atomically:YES];
	notify_post("libactivator.preferenceschanged");
	[cell setAccessoryType:accessory];
	[cell setSelected:NO animated:YES];
}

@end
