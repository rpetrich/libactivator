#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#include <stdlib.h>

__attribute__((always_inline))
static inline NSString *SCRootPath(NSString *path)
{
#ifdef TARGET_IPHONE_SIMULATOR
	char *rootPath = getenv("IPHONE_SIMULATOR_ROOT");
	if (rootPath)
		return [NSString stringWithFormat:@"%s%@", rootPath, path];
#endif
	return path;
}

__attribute__((always_inline))
static inline NSString *SCMobilePath(NSString *path)
{
#ifdef TARGET_IPHONE_SIMULATOR
	char *mobilePath = getenv("IPHONE_SHARED_RESOURCES_DIRECTORY");
	if (mobilePath)
		return [NSString stringWithFormat:@"%s%@", mobilePath, path];
#endif
	return [@"/var/mobile" stringByAppendingString:path];
}
