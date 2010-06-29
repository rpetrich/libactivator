#import "ActivatorEventViewHeader.h"
#import "libactivator.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit2.h>

@implementation ActivatorEventViewHeader

@synthesize delegate = _delegate;

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		[self setOpaque:YES];
		[self setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	}
	return self;
}

- (NSString *)listenerName
{
	return _listenerName;
}

- (void)setListenerName:(NSString *)listenerName
{
	if (![_listenerName isEqualToString:listenerName]) {
		[_listenerName release];
		_listenerName = [listenerName copy];
		[self setNeedsDisplay];
		CATransition *animation = [CATransition animation];
		[animation setType:kCATransitionFade];
		//[animation setDuration:0.3];
		[[self layer] addAnimation:animation forKey:kCATransition];
	}
}

- (void)drawRect:(CGRect)rect
{
	[[UIColor tableSeparatorDarkColor] setFill];
	CGContextRef c = UIGraphicsGetCurrentContext();
	CGSize shadowOffset = CGSizeMake(0.0f, -1.0f);
	shadowOffset.width = 0.0f;
	shadowOffset.height = [UIDevice instancesRespondToSelector:@selector(isWildcat)] ? 1.0f : -1.0f;
	CGContextSetShadowWithColor(c, shadowOffset, 0.0f, [[UIColor tableSeparatorLightColor] CGColor]);
	CGRect line = [self bounds];
	line.origin.x = 15.0f;
	line.size.width -= 30.0f;
	line.origin.y = line.size.height - 2.0f;
	line.size.height = 1.0f;
	UIRectFill(line);
	[[UIColor colorWithRed:0.3f green:0.34f blue:0.42f alpha:1.0f] setFill];
	CGContextSetShadowWithColor(c, shadowOffset, 0.0f, [[UIColor whiteColor] CGColor]);
	[[LASharedActivator localizedStringForKey:@"CURRENTLY_ASSIGNED_TO" value:@"Currently assigned to:"] drawAtPoint:CGPointMake(20.0f, 9.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	if ([_listenerName length]) {
		// Draw Close Button
		CGContextBeginPath(c);
		CGRect closeRect;
		closeRect.origin.x = line.size.width - 5;
		closeRect.origin.y = 40.0f;
		closeRect.size.width = 20.0f;
		closeRect.size.height = 20.0f;
		CGContextAddEllipseInRect(c, closeRect);
		const CGFloat lineWidth = 1.25f;
		const CGPoint points[] = {
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4) + lineWidth, closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 2), closeRect.origin.y + (closeRect.size.height / 2) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4) - lineWidth, closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height / 4) + lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 2) + lineWidth, closeRect.origin.y + (closeRect.size.height / 2) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width * 3 / 4) - lineWidth, closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 2), closeRect.origin.y + (closeRect.size.height / 2) + lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 4) + lineWidth, closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height * 3 / 4) - lineWidth },
			{ closeRect.origin.x + (closeRect.size.width / 2) - lineWidth, closeRect.origin.y + (closeRect.size.height / 2) },
			{ closeRect.origin.x + (closeRect.size.width / 4), closeRect.origin.y + (closeRect.size.height / 4) + lineWidth }
		};
		CGContextAddLines(c, points, 16);
		CGContextClosePath(c);
		CGContextEOFillPath(c);
		// Draw Image
		UIImage *image = [LASharedActivator smallIconForListenerName:_listenerName];
		CGFloat x;
		if (image) {
			[image drawAtPoint:CGPointMake(20.0f, 35.0f)];
			x = 30.0f + [image size].width;
		} else {
			x = 30.0f;
		}
		// Draw Text
		[[UIColor blackColor] setFill];
		[[LASharedActivator localizedTitleForListenerName:_listenerName] drawAtPoint:CGPointMake(x, 39.0f) withFont:[UIFont boldSystemFontOfSize:19.0f]];
	} else {
		[[LASharedActivator localizedStringForKey:@"UNASSIGNED" value:@"(unassigned)"] drawAtPoint:CGPointMake(30.0f, 40.0f) withFont:[UIFont boldSystemFontOfSize:17.0f]];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	[_delegate eventViewHeaderCloseButtonTapped:self];
}

@end
