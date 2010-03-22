#import <libactivator/libactivator.h>
#import <UIKit/UIKit.h>

@interface ExampleListener : NSObject<LAListener, UIAlertViewDelegate> {
// Class Name ^^ should be changed to the name of your Extension
@private
	UIAlertView *av;
}
@end

@implementation ExampleListener

- (BOOL)dismiss
{
	// Ensures alert view is dismissed
	// Returns YES if alert was visible previously
	if (av) {
		[av dismissWithClickedButtonIndex:[av cancelButtonIndex] animated:YES];
		[av release];
		av = nil;
		return YES;
	}
	return NO;
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
	[av release];
	av = nil;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	// Called when we recieve event
	if (![self dismiss]) {
		av = [[UIAlertView alloc] initWithTitle:@"Example Listener" message:[event name] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[av show];
		[event setHandled:YES];
	}
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	// Called when event is escalated to a higher event
	// (short-hold sleep button becomes long-hold shutdown menu, etc)
	[self dismiss];
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
	// Called when some other listener received an event; we should cleanup
	[self dismiss];
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	// Called when the home button is pressed.
	// If (and only if) we are showing UI, we should dismiss it and call setHandled:
	if ([self dismiss])
		[event setHandled:YES];
}

- (void)dealloc
{
	// Since this object lives for the lifetime of SpringBoard, this will never be called
	// It's here for the sake of completeness
	[av release];
	[super dealloc];
}

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Register our listener
	[[LAActivator sharedInstance] registerListener:[self new] forName:@"libactivator.examplelistener"];
	[pool release];
}

@end 