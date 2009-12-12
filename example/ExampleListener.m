#import <libactivator/libactivator.h>
#import <UIKit/UIKit.h>

@interface ExampleListener : NSObject<LAListener> {
@private
	UIAlertView *av;
}
@end

@implementation ExampleListener

- (void)dismiss
{
	if (av) {
		[av dismissWithClickedButtonIndex:[av cancelButtonIndex] animated:YES];
		[av release];
		av = nil;
	}
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	[self dismiss];
	av = [[UIAlertView alloc] initWithTitle:@"Example Listener" message:[event name] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[av show];
	[event setHandled:YES];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[self dismiss];
}

+ (void)load
{
	[[LAActivator sharedInstance] registerListener:[self new] forName:@"libactivator.examplelistener"];
}

@end 