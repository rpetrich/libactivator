#import "libactivator-private.h"
#import "SimulatorCompat.h"

@implementation LADefaultEventDataSource

static LADefaultEventDataSource *sharedInstance;

+ (void)initialize
{
	if (self == [LADefaultEventDataSource class])
		sharedInstance = [[self alloc] init];
}

+ (LADefaultEventDataSource *)sharedInstance
{
	return sharedInstance;
}

- (id)init
{
	if ((self = [super init])) {
		// Cache event data
		_eventData = [[NSMutableDictionary alloc] init];
		NSString *eventsPath = SCRootPath(@"/Library/Activator/Events");
		if (LASharedActivator.runningInsideSpringBoard) {
			for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:eventsPath error:NULL])
				if (![fileName hasPrefix:@"."]) {
					[_eventData setObject:[NSBundle bundleWithPath:[eventsPath stringByAppendingPathComponent:fileName]] forKey:fileName];
				[LASharedActivator registerEventDataSource:self forEventName:fileName];
			}
		}
	}
	return self;
}

- (void)dealloc
{
	if (LASharedActivator.runningInsideSpringBoard)
		for (NSString *eventName in [_eventData allKeys])
			[LASharedActivator unregisterEventDataSourceWithEventName:eventName];
	[_eventData release];
	[super dealloc];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"title"] ?: eventName;
	return Localize(activatorBundle, [@"EVENT_TITLE_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized) ?: eventName);
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
	if ([unlocalized length] == 0)
		return @"";
	return Localize(activatorBundle, [@"EVENT_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized) ?: @"");
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
	if (unlocalized)
		return Localize(activatorBundle, [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized));
	NSString *key = [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName];
	NSString *result = Localize(activatorBundle, key, nil);
	return [result isEqualToString:key] ? nil : result;
}

- (BOOL)eventWithNameIsHidden:(NSString *)eventName
{
	return [[[_eventData objectForKey:eventName] objectForInfoDictionaryKey:@"hidden"] boolValue];
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
	if (eventMode) {
		NSArray *compatibleModes = [[_eventData objectForKey:eventName] objectForInfoDictionaryKey:@"compatible-modes"];
		if (compatibleModes)
			return [compatibleModes containsObject:eventMode];
	}
	return YES;
}

@end
