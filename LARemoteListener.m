#import "LARemoteListener.h"
#import "libactivator-private.h"

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

- (void)_performRemoteSelector:(SEL)selector withEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", [NSKeyedArchiver archivedDataWithRootObject:event], @"event", nil];
	NSData *result = [[messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
	LAEvent *newEvent = [NSKeyedUnarchiver unarchiveObjectWithData:result];
	[event setHandled:[newEvent isHandled]];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self _performRemoteSelector:_cmd withEvent:event forListenerName:listenerName];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
	[self _performRemoteSelector:_cmd withEvent:event forListenerName:listenerName];
}

- (id)_performRemoteSelector:(SEL)selector withObject:(id)object withObject:(id)object2 forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", object, @"object", object2, @"object2", nil];
	return [[messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo] objectForKey:@"result"];
}

- (id)_performRemoteSelector:(SEL)selector withObject:(id)object withScalePtr:(CGFloat *)scale forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", [NSNumber numberWithFloat:*scale], @"scale", object, @"object", nil];
	NSDictionary *result = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	*scale = [[result objectForKey:@"scale"] floatValue];
	return [result objectForKey:@"result"];
}

- (UIImage *)_performRemoteImageSelector:(SEL)selector withObject:(id)object withScale:(CGFloat)scale forListenerName:(NSString *)listenerName
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:listenerName, @"listenerName", [NSNumber numberWithFloat:scale], @"scale", object, @"object", nil];
	NSDictionary *result = [messagingCenter sendMessageAndReceiveReplyName:NSStringFromSelector(selector) userInfo:userInfo];
	NSData *data = [result objectForKey:@"data"];
	if (data) {
		size_t width = [[result objectForKey:@"width"] longValue];
		size_t height = [[result objectForKey:@"height"] longValue];
		size_t bitsPerComponent = [[result objectForKey:@"bitsPerComponent"] longValue];
		size_t bitsPerPixel = [[result objectForKey:@"bitsPerPixel"] longValue];
		size_t bytesPerRow = [[result objectForKey:@"bytesPerRow"] longValue];
		CGBitmapInfo bitmapInfo = [[result objectForKey:@"bitmapInfo"] longValue];
		CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGImageRef cgImage = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpace, bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
		CGColorSpaceRelease(colorSpace);
		CGDataProviderRelease(provider);
		UIImage *image = [UIImage imageWithData:[result objectForKey:@"result"]];
		if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
			image = [UIImage imageWithCGImage:cgImage scale:[[result objectForKey:@"scale"] floatValue] orientation:[[result objectForKey:@"orientation"] longValue]];
		} else {
			image = [UIImage imageWithCGImage:cgImage];
		}
		CGImageRelease(cgImage);
		return image;
	}
	return nil;
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedGroupForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSNumber *)activator:(LAActivator *)activator requiresRequiresAssignmentForListenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName
{
	// Read data without CPDistributedMessagingCenter if possible
	return [super activator:activator requiresIconDataForListenerName:listenerName]
		?: [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	// Read data without CPDistributedMessagingCenter if possible
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
	return [self _performRemoteSelector:_cmd withObject:listenerName withScalePtr:scale forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName
{
	// Read data without CPDistributedMessagingCenter if possible
	return [super activator:activator requiresSmallIconDataForListenerName:listenerName]
		?: [self _performRemoteSelector:_cmd withObject:listenerName withObject:nil forListenerName:listenerName];
}
- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
	// Read data without CPDistributedMessagingCenter if possible
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
	return [self _performRemoteSelector:_cmd withObject:listenerName withScalePtr:scale forListenerName:listenerName];
}
- (NSNumber *)activator:(LAActivator *)activator requiresIsCompatibleWithEventName:(NSString *)eventName listenerName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:eventName withObject:listenerName forListenerName:listenerName];
}
- (id)activator:(LAActivator *)activator requiresInfoDictionaryValueOfKey:(NSString *)key forListenerWithName:(NSString *)listenerName
{
	return [self _performRemoteSelector:_cmd withObject:key withObject:listenerName forListenerName:listenerName];
}

- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	return [self _performRemoteImageSelector:_cmd withObject:listenerName withScale:scale forListenerName:listenerName];
}

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	if ([applicationDisplayIdentifiers containsObject:listenerName]) {
		UIImage *result = [UIImage _applicationIconImageForBundleIdentifier:listenerName format:0 scale:scale];
		if (result)
			return result;
	}
	return [self _performRemoteImageSelector:_cmd withObject:listenerName withScale:scale forListenerName:listenerName];
}


@end
