#import "LARemoteListener.h"
#import "libactivator-private.h"
#import "LAMessaging.h"

#import <AppSupport/AppSupport.h>

static LARemoteListener *sharedInstance;
static NSSet *applicationDisplayIdentifiers;

CFArrayRef SBSCopyApplicationDisplayIdentifiers(bool activeOnly, bool debugCapable);

@implementation LARemoteListener

+ (void)initialize
{
	if (self == [LARemoteListener class]) {
		if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
			CFArrayRef displayIdentifiers = SBSCopyApplicationDisplayIdentifiers(false, false);
			if (displayIdentifiers) {
				applicationDisplayIdentifiers = [[NSSet alloc] initWithArray:(NSArray *)displayIdentifiers];
				CFRelease(displayIdentifiers);
			}
		}
		sharedInstance = [[self alloc] init];
	}
}

+ (LARemoteListener *)sharedInstance
{
	return sharedInstance;
}

static inline void LASendEventMessage(SInt32 messageId, LAEvent *event, NSString *listenerName)
{
	NSMutableData *data = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[archiver encodeObject:event forKey:@"event"];
	[archiver encodeObject:listenerName forKey:@"listenerName"];
	[archiver finishEncoding];
	event.handled = LAConsume(LATransformDataToBOOL, LASendTwoWayMessage(messageId, (CFDataRef)data), NO);
	[archiver release];
	[data release];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	LASendEventMessage(LAMessageIdReceiveEventForListenerName, event, listenerName);
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	LASendEventMessage(LAMessageIdAbortEventForListenerName, event, listenerName);
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedTitleForListenerName, (CFDataRef)LATransformStringToData(listenerName)), nil);
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedDescriptionForListenerName, (CFDataRef)LATransformStringToData(listenerName)), nil);
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return LAConsume(LATransformDataToString, LASendTwoWayMessage(LAMessageIdGetLocalizedGroupForListenerName, (CFDataRef)LATransformStringToData(listenerName)), nil);
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetRequiresAssignmentForListenerName, (CFDataRef)LATransformStringToData(listenerName)), nil);
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetCompatibleEventModesForListenerName, (CFDataRef)LATransformStringToData(listenerName)), nil);
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	// Read data without IPC if possible
	NSData *result = [super activator:activator requiresIconDataForListenerName:listenerName];
	if (result)
		return result;
	result = [(NSData *)LASendTwoWayMessage(LAMessageIdGetIconDataForListenerName, (CFDataRef)LATransformStringToData(listenerName)) autorelease];
	return [result length] ? result : nil;
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	// Read data without IPC if possible
	NSBundle *bundle = ListenerBundle(listenerName);
	NSData *result;
	CGFloat scaleCopy = *scale;
	if (scaleCopy != 1.0f) {
		result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-fallback@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-fallback@%.0fx", scaleCopy] ofType:@"png"]];
		if (result)
			return result;
	}
	result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon-fallback" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon-fallback" ofType:@"png"]];
	if (result) {
		*scale = 1.0f;
		return result;
	}
	NSArray *args = [NSArray arrayWithObjects:listenerName, [NSNumber numberWithFloat:scaleCopy], nil];
	CFDataRef headeredResult = LASendTwoWayMessage(LAMessageIdGetIconDataForListenerNameWithScale, (CFDataRef)LATransformPropertyListToData(args));
	if (headeredResult) {
		CFIndex dataLength = CFDataGetLength(headeredResult);
		if (dataLength >= sizeof(CGFloat)) {
			const UInt8 *bytes = CFDataGetBytePtr(headeredResult);
			const CGFloat *actualScale = (const CGFloat *)bytes;
			*scale = *actualScale;
			// TODO: Have this not make a copy
			result = [NSData dataWithBytes:bytes + sizeof(CGFloat) length:dataLength - sizeof(CGFloat)];
		}
		CFRelease(headeredResult);
	}
	return result;
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	// Read data without IPC if possible
	NSData *result = [super activator:activator requiresSmallIconDataForListenerName:listenerName];
	if (result)
		return result;
	result = [(NSData *)LASendTwoWayMessage(LAMessageIdGetSmallIconDataForListenerName, (CFDataRef)LATransformStringToData(listenerName)) autorelease];
	return [result length] ? result : nil;
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	// Read data without IPC if possible
	NSBundle *bundle = ListenerBundle(listenerName);
	NSData *result;
	CGFloat scaleCopy = *scale;
	if (scaleCopy != 1.0f) {
		result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-small@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-small@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"icon-small-fallback@%.0fx", scaleCopy] ofType:@"png"]]
		      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:[NSString stringWithFormat:@"Icon-small-fallback@%.0fx", scaleCopy] ofType:@"png"]];
		if (result)
			return result;
	}
	result = [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon-small" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon-small" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"icon-small-fallback" ofType:@"png"]]
	      ?: [NSData dataWithContentsOfMappedFile:[bundle pathForResource:@"Icon-small-fallback" ofType:@"png"]];
	if (result) {
		*scale = 1.0f;
		return result;
	}		
	NSArray *args = [NSArray arrayWithObjects:listenerName, [NSNumber numberWithFloat:scaleCopy], nil];
	CFDataRef headeredResult = LASendTwoWayMessage(LAMessageIdGetSmallIconDataForListenerNameWithScale, (CFDataRef)LATransformPropertyListToData(args));
	if (headeredResult) {
		CFIndex dataLength = CFDataGetLength(headeredResult);
		if (dataLength >= sizeof(CGFloat)) {
			const UInt8 *bytes = CFDataGetBytePtr(headeredResult);
			const CGFloat *actualScale = (const CGFloat *)bytes;
			*scale = *actualScale;
			// TODO: Have this not make a copy
			result = [NSData dataWithBytes:bytes + sizeof(CGFloat) length:dataLength - sizeof(CGFloat)];
		}
		CFRelease(headeredResult);
	}
	return result;
}
- (NSNumber *)activator:(LAActivator *)activator requiresIsCompatibleWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName
{
	NSArray *args = [NSArray arrayWithObjects:listenerName, eventName, nil];
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetListenerNameIsCompatibleWithEventName, (CFDataRef)LATransformPropertyListToData(args)), nil);
}
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName
{
	NSArray *args = [NSArray arrayWithObjects:listenerName, key, nil];
	return LAConsume(LATransformDataToPropertyList, LASendTwoWayMessage(LAMessageIdGetValueOfInfoDictionaryKeyForListenerName, (CFDataRef)LATransformPropertyListToData(args)), nil);
}

- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	NSArray *args = [NSArray arrayWithObjects:listenerName, [NSNumber numberWithFloat:scale], nil];
	return LAConsume(LATransformDataToUIImage, LASendTwoWayMessage(LAMessageIdGetIconWithScaleForListenerName, (CFDataRef)LATransformPropertyListToData(args)), nil);
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	if ([applicationDisplayIdentifiers containsObject:listenerName]) {
		UIImage *result = [UIImage _applicationIconImageForBundleIdentifier:listenerName format:0 scale:scale];
		if (result)
			return result;
	}
	NSArray *args = [NSArray arrayWithObjects:listenerName, [NSNumber numberWithFloat:scale], nil];
	return LAConsume(LATransformDataToUIImage, LASendTwoWayMessage(LAMessageIdGetSmallIconWithScaleForListenerName, (CFDataRef)LATransformPropertyListToData(args)), nil);
}


@end
