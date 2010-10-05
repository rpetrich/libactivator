#import "libactivator-private.h"

@implementation NSObject (LAEventDataSource)

- (BOOL)eventWithNameIsHidden:(NSString *)eventName
{
   return NO;
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode
{
   return YES;
}

@end