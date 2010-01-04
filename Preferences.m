#import <Preferences/Preferences.h>

#import "libactivator.h"

@interface ActivatorSettingsController : PSViewController {
@private
	NSString *_title;
	LAListenerSettingsViewController *_viewController;
	CGSize _size;
}
@end

@implementation ActivatorSettingsController

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		_viewController = [[LAListenerSettingsViewController alloc] init];
		_size = size;
	}
	return self;
}

- (void)dealloc
{
	[_viewController release];
	[_title release];
	[super dealloc];
}

- (void)viewWillBecomeVisible:(void *)source
{
	if (source == NULL)
		NSLog(@"libactivator: No PSSpecifier specified!");
	else {
		PSSpecifier *specifier = (PSSpecifier *)source;
		NSString *listenerName = [specifier propertyForKey:@"activatorListener"];
		if ([listenerName length] == 0)
			NSLog(@"libactivator: No activatorListener key specified on PSSpecifier");
		else {
			[_viewController setListenerName:listenerName];
			NSString *modeName = [specifier propertyForKey:@"activatorEventMode"];
			if (modeName)
				[_viewController setEventMode:modeName];
			CGRect frame;
			frame.origin.x = 0.0f;
			frame.origin.y = 0.0f;
			frame.size = _size;
			[[_viewController view] setFrame:frame];
			[_title release];
			_title = [[specifier propertyForKey:@"activatorTitle"]?:[specifier name] copy];
		}
	}
	[super viewWillBecomeVisible:source];
}

- (NSString *)navigationTitle
{
	if ([_title length])
		return _title;
	else
		return [_viewController listenerName];
}

- (UIView *)view
{
	return [_viewController view];
}

@end
