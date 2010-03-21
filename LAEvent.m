#import "libactivator.h"

@implementation LAEvent

@synthesize name = _name;
@synthesize mode = _mode;
@synthesize handled = _handled;

+ (id)eventWithName:(NSString *)name
{
	return [[[self alloc] initWithName:name] autorelease];
}

+ (id)eventWithName:(NSString *)name mode:(NSString *)mode
{
	return [[[self alloc] initWithName:name mode:mode] autorelease];
}

- (id)initWithName:(NSString *)name
{
	if ((self = [super init])) {
		_name = [name copy];
	}
	return self;
}

- (id)initWithName:(NSString *)name mode:(NSString *)mode
{
	if ((self = [super init])) {
		_name = [name copy];
		_mode = [mode copy];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init])) {
		_name = [[coder decodeObjectForKey:@"name"] copy];
		_mode = [[coder decodeObjectForKey:@"mode"] copy];
		_handled = [coder decodeBoolForKey:@"handled"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_mode forKey:@"mode"];
	[coder encodeBool:_handled forKey:@"handled"];
}

- (id)copyWithZone:(NSZone *)zone
{
	id result = [[LAEvent allocWithZone:zone] initWithName:_name mode:_mode];
	[result setHandled:_handled];
	return result;
}

- (void)dealloc
{
	[_name release];
	[_mode release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<LAEvent name=%@ mode=%@ handled=%s %p>", _name, _mode, _handled?"YES":"NO", self];
}

@end
