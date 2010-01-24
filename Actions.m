#import "libactivator.h"
#import "libactivator-private.h"
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <GraphicsServices/GraphicsServices.h>
#import <CaptainHook/CaptainHook.h>

CHDeclareClass(SBIconController);
CHDeclareClass(SBSearchController);

@interface SystemActivator : NSObject<LAListener> {
	SEL _action;
}
- (id)initWithAction:(SEL)action;
@end

@implementation SystemActivator

- (void)homebutton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventMenuButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventMenuButtonUp;
	GSSendSystemEvent(&record);	
}

- (void)sleepbutton
{
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.type = kGSEventLockButtonDown;
	record.timestamp = GSCurrentEventTimestamp();
	GSSendSystemEvent(&record);
	record.type = kGSEventLockButtonUp;
	GSSendSystemEvent(&record);	
}

- (void)respring
{
	[(SpringBoard *)[UIApplication sharedApplication] relaunchSpringBoard];
}

/* // A safemode method isn't needed; it should safe mode anyway :P
- (void)safemode
{
	[(SpringBoard *)[UIApplication sharedApplication] enterSafeMode];
}*/

- (void)reboot
{
	[(SpringBoard *)[UIApplication sharedApplication] reboot];
}

- (void)powerdown
{
	[(SpringBoard *)[UIApplication sharedApplication] powerDown];
}

- (void)spotlight
{
	[[LAActivator sharedInstance] _activateApplication:nil];
	[CHSharedInstance(SBIconController) scrollToIconListAtIndex:-1 animate:NO];
	[[CHSharedInstance(SBSearchController) searchView] setShowsKeyboard:YES animated:YES];	
}

- (id)initWithAction:(SEL)action
{
	if ((self = [super init])) {
		_action = action;
	}
	return self;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	objc_msgSend(self, _action);
}

#define RegisterAction(name) \
	[activator registerListener:[[self alloc] initWithAction:@selector(name)] forName:@"libactivator.system." #name]
	
+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	LAActivator *activator = [LAActivator sharedInstance];
	RegisterAction(homebutton);
	RegisterAction(sleepbutton);
	RegisterAction(respring);
	RegisterAction(safemode);
	RegisterAction(reboot);
	RegisterAction(powerdown);
	RegisterAction(spotlight);
	CHLoadLateClass(SBIconController);
	CHLoadLateClass(SBSearchController);
	[pool release];
}

@end 