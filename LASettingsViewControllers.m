#import "Settings.h"
#import <dlfcn.h>

// Stub implementations of settings controller APIs
// Was a mistake to include these in the standard library that everyone links to
// First time any settings controller API is used, load the real implementations

@implementation LASettingsViewController

+ (void)initialize
{
	if (self == [LASettingsViewController class]) {
		dlopen("/Library/Activator/Settings.dylib", RTLD_LAZY);
	}
}

@end

@implementation LARootSettingsController
@end

@implementation LAModeSettingsController
@end

@implementation LAEventSettingsController
@end

@implementation LAListenerSettingsViewController
@end
