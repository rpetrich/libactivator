#import "libactivator.h"

__attribute__((visibility("hidden")))
@interface LADefaultEventDataSource : NSObject<LAEventDataSource> {
   NSMutableDictionary *_eventData;
}

+ (LADefaultEventDataSource *)sharedInstance;

- (NSString *)localizedTitleForEventName:(NSString *)eventName;
- (NSString *)localizedGroupForEventName:(NSString *)eventName;
- (NSString *)localizedDescriptionForEventName:(NSString *)eventName;
- (BOOL)eventWithNameIsHidden:(NSString *)eventName;
- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode;

@end

