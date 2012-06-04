#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import "libactivator-private.h"
#define kLAMessageServerName CFSTR("libactivator.springboard")
#define kLAMessageWaitingRunLoopMode CFSTR("libactivator.waiting-on-springboard")

enum {
	LAMessageIdResetPreferences = 0, // oneway, no input
	LAMessageIdGetPreference = 1, // twoway, string input, plist output
	LAMessageIdSetPreference = 2, // oneway, plist input
	LAMessageIdGetAvaliableEventNames = 3, // twoway, no input, plist output
	LAMessageIdGetEventIsHidden = 4, // twoway, string input, bool output
	LAMessageIdGetCompatibleModesForEventName = 5, // twoway, string input, plist output
	LAMessageIdGetEventWithNameIsCompatibleWithMode = 6, // twoway, plist input, bool output
	LAMessageIdGetListenerNames = 7, // twoway, no input, plist output
	LAMessageIdGetCachedAnsSortedListeners = 8, // twoway, no input, plist output
	LAMessageIdGetCurrentEventMode = 9, // twoway, no input, string output
	LAMessageIdGetDisplayIdentifierForCurrentApplication = 10, // twoway, no input, string output
	LAMessageIdGetLocalizedTitleForEventName = 11, // twoway, string input, string output
	LAMessageIdGetLocalizedDescriptionForEventName = 12, // twoway, string input, string output
	LAMessageIdGetLocalizedGroupForEventName = 13, // twoway, string input, string output
	LAMessageIdSendDeactivateEventToListeners = 14, // twoway, coder input, bool output
	LAMessageIdReceiveEventForListenerName = 15, // twoway, coder input, bool output
	LAMessageIdAbortEventForListenerName = 16, // twoway, coder input, bool output
	LAMessageIdGetLocalizedTitleForListenerName = 17, // twoway, string input, string output
	LAMessageIdGetLocalizedDescriptionForListenerName = 18, // twoway, string input, string output
	LAMessageIdGetLocalizedGroupForListenerName = 19, // twoway, string input, string output
	LAMessageIdGetRequiresAssignmentForListenerName = 20, // twoway, string input, plist output
	LAMessageIdGetCompatibleEventModesForListenerName = 21, // twoway, string input, plist output
	LAMessageIdGetIconDataForListenerName = 22, // twoway, string input, data output
	LAMessageIdGetIconDataForListenerNameWithScale = 23, // twoway, plist input, data output with CGFloat header
	LAMessageIdGetIconWithScaleForListenerName = 24, // twoway, plist input, image output
	LAMessageIdGetSmallIconDataForListenerName = 25, // twoway, string input, data output
	LAMessageIdGetSmallIconDataForListenerNameWithScale = 26, // twoway, plist input, data output with CGFloat header
	LAMessageIdGetSmallIconWithScaleForListenerName = 27, // twoway, plist input, plist output
	LAMessageIdGetListenerNameIsCompatibleWithEventName = 28, // twoway, plist input, plist output
	LAMessageIdGetValueOfInfoDictionaryKeyForListenerName = 29, // twoway, plist input, plist output
};

#define LAConsume(transformer, data, defaultValue) ({ \
	__typeof__(data) _data = data; \
	__typeof__(transformer(_data)) result; \
	if (_data) { \
		result = transformer(_data); \
		CFRelease((CFTypeRef)_data); \
	} else { \
		result = defaultValue; \
	} \
	result; \
})

// Remote functions

static inline CFMessagePortRef LAGetServerPort()
{
	if (serverPort && CFMessagePortIsValid(serverPort))
		return serverPort;
	return (serverPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kLAMessageServerName));
}

static inline void LASendOneWayMessage(SInt32 messageId, CFDataRef data)
{
	CFMessagePortRef messagePort = LAGetServerPort();
	if (messagePort) {
		CFMessagePortSendRequest(messagePort, messageId, data, 45.0, 45.0, NULL, NULL);
	}
}

static inline CFDataRef LASendTwoWayMessage(SInt32 messageId, CFDataRef data)
{
	CFDataRef outData = NULL;
	CFMessagePortRef messagePort = LAGetServerPort();
	if (messagePort) {
		CFMessagePortSendRequest(messagePort, messageId, data, 45.0, 45.0, kLAMessageWaitingRunLoopMode, &outData);
	}
	return outData;
}

// Helper functions

static inline id LATransformDataToPropertyList(CFDataRef data)
{
	return [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
}

static inline NSData *LATransformPropertyListToData(id propertyList)
{
	return [NSPropertyListSerialization dataFromPropertyList:propertyList format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
}


static inline NSString *LATransformDataToString(CFDataRef data)
{
	return [[[NSString alloc] initWithData:(NSData *)data encoding:NSUTF8StringEncoding] autorelease];
}

static inline NSData *LATransformStringToData(NSString *string)
{
	return [string dataUsingEncoding:NSUTF8StringEncoding];
}


static inline BOOL LATransformDataToBOOL(CFDataRef data)
{
	return CFDataGetLength(data) != 0;
}

typedef struct {
	size_t width;
	size_t height;
	size_t bitsPerComponent;
	size_t bitsPerPixel;
	size_t bytesPerRow;
	CGBitmapInfo bitmapInfo;
	CGFloat scale;
	UIImageOrientation orientation;
} LAImageHeader;


static inline NSData *LATransformUIImageToData(UIImage *image)
{
	if (!image)
		return nil;
	CGImageRef cgImage = image.CGImage;
	if (!cgImage)
		return nil;
	CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
	if (!imageData)
		return nil;
	LAImageHeader header;
	header.width = CGImageGetWidth(cgImage);
	header.height = CGImageGetHeight(cgImage);
	header.bitsPerComponent = CGImageGetBitsPerComponent(cgImage);
	header.bitsPerPixel = CGImageGetBitsPerPixel(cgImage);
	header.bytesPerRow = CGImageGetBytesPerRow(cgImage);
	header.bitmapInfo = CGImageGetBitmapInfo(cgImage);
	header.scale = [image respondsToSelector:@selector(scale)] ? [image scale] : 1.0f;
	header.orientation = image.imageOrientation;
	NSMutableData *result = [NSMutableData dataWithCapacity:sizeof(LAImageHeader) + CFDataGetLength(imageData)];
	[result appendBytes:&header length:sizeof(LAImageHeader)];
	[result appendData:(NSData *)imageData];
	CFRelease(imageData);
	return result;
}

static void LACGDataProviderReleaseCallback(void *info, const void *data, size_t size)
{
	CFRelease(info);
}

static inline UIImage *LATransformDataToUIImage(CFDataRef data)
{
	if (!data)
		return nil;
	CFIndex dataLength = CFDataGetLength(data);
	if (dataLength < sizeof(LAImageHeader))
		return nil;
	const UInt8 *bytes = CFDataGetBytePtr(data);
	const LAImageHeader *header = (const LAImageHeader *)bytes;
	CGDataProviderRef provider = CGDataProviderCreateWithData((void *)data, bytes + sizeof(LAImageHeader), dataLength - sizeof(LAImageHeader), LACGDataProviderReleaseCallback);
	if (provider) {
		CFRetain(data);
		//CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGImageRef cgImage = CGImageCreate(header->width, header->height, header->bitsPerComponent, header->bitsPerPixel, header->bytesPerRow, colorSpace, header->bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
		CGColorSpaceRelease(colorSpace);
		CGDataProviderRelease(provider);
		if (cgImage) {
			UIImage *image;
			if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
				image = [UIImage imageWithCGImage:cgImage scale:header->scale orientation:header->orientation];
			} else {
				image = [UIImage imageWithCGImage:cgImage];
			}
			CGImageRelease(cgImage);
			return image;
		}
	}
	return nil;
}
