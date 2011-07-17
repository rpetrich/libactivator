#import <UIKit/UIKit.h>
#import "libactivator.h"

int main(int argc, char *argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, @"ActivatorApplicationDelegate");
    [pool release];
    return retVal;
}

@interface ActivatorApplicationDelegate : NSObject <UIApplicationDelegate> {
@private
	UIWindow *window;
	UINavigationController *navigationController;
	UIViewController *viewController;
}
@end

@implementation ActivatorApplicationDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	viewController = [[LARootSettingsController alloc] init];
	navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
	window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	if ([window respondsToSelector:@selector(setRootViewController:)])
		[window setRootViewController:navigationController];
	else
		[window addSubview:navigationController.view];
	[window makeKeyAndVisible];
}

@end
