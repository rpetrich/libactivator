#import "LADefaultEventDataSource.h"
#import "SimulatorCompat.h"
#import "libactivator-private.h"

@implementation LADefaultEventDataSource

static LADefaultEventDataSource *sharedDefaultEventDataSource;

+ (void)initialize
{
	if (self == [LADefaultEventDataSource class])
		sharedDefaultEventDataSource = [[self alloc] init];
}

+ (LADefaultEventDataSource *)sharedInstance
{
	return sharedDefaultEventDataSource;
}

- (id)init
{
	if ((self = [super init])) {
		// Cache event data
		_eventData = [[NSMutableDictionary alloc] init];
		Class arrayClass = [NSArray class];
		NSString *eventsPath = SCRootPath(@"/Library/Activator/Events");
		for (NSString *fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:eventsPath error:NULL]) {
			if (![fileName hasPrefix:@"."]) {
				NSBundle *bundle = [NSBundle bundleWithPath:[eventsPath stringByAppendingPathComponent:fileName]];
				NSArray *foundationVersion = [bundle objectForInfoDictionaryKey:@"CoreFoundationVersion"];
				if ([foundationVersion isKindOfClass:arrayClass]) {
					switch ([foundationVersion count]) {
						case 2:
							if ([[foundationVersion objectAtIndex:1] doubleValue] <= kCFCoreFoundationVersionNumber)
								goto skip;
						case 1:
							if ([[foundationVersion objectAtIndex:0] doubleValue] > kCFCoreFoundationVersionNumber)
								goto skip;
							break;
						default:
							goto skip;
					}
				}
				[_eventData setObject:bundle forKey:fileName];
				[LASharedActivator registerEventDataSource:self forEventName:fileName];
			skip:;
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
	return Localize(LASharedActivator.bundle, [@"EVENT_TITLE_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized) ?: eventName);
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"group"] ?: @"";
	if ([unlocalized length] == 0)
		return @"";
	return Localize(LASharedActivator.bundle, [@"EVENT_GROUP_TITLE_" stringByAppendingString:unlocalized], Localize(bundle, unlocalized, unlocalized) ?: @"");
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName
{
	NSBundle *bundle = [_eventData objectForKey:eventName];
	NSString *unlocalized = [bundle objectForInfoDictionaryKey:@"description"];
	NSBundle *aBundle = LASharedActivator.bundle;
	if (unlocalized)
		return Localize(aBundle, [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName], Localize(bundle, unlocalized, unlocalized));
	NSString *key = [@"EVENT_DESCRIPTION_" stringByAppendingString:eventName];
	NSString *result = Localize(aBundle, key, nil);
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
