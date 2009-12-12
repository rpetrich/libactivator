#import <Foundation/Foundation.h>

#include <notify.h>
#include <sys/stat.h>
#include <string.h>

#import <CaptainHook/CaptainHook.h>

#define kPreferencesFilePath "/User/Library/Preferences/libactivator.plist"

static inline void SavePreferences(NSDictionary *prefs)
{
	[prefs writeToFile:@kPreferencesFilePath atomically:YES];
	chmod(kPreferencesFilePath, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
	notify_post("libactivator.preferenceschanged");
}

int main(int argc, char *argv[])
{
	CHAutoreleasePoolForScope();
	NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@kPreferencesFilePath];
	if (!prefs)
		prefs = [NSMutableDictionary dictionary];
	switch (argc) {
		case 3:
			if (strcmp(argv[1], "set") == 0) {
				NSString *preferenceName = [NSString stringWithFormat:@"LAEventListener-%s", argv[2]];
				[prefs removeObjectForKey:preferenceName];
				SavePreferences(prefs);
				return 0;
			} else if (strcmp(argv[1], "clear-all") == 0) {
				NSString *listenerToClear = [NSString stringWithUTF8String:argv[2]];
				for (NSString *key in [prefs allKeys]) {
					if ([key hasPrefix:@"LAEventListener-"] && [listenerToClear isEqualToString:[prefs objectForKey:key]])
						[prefs removeObjectForKey:key];
				}
				SavePreferences(prefs);
				return 0;
			}
			break;
		case 4:
			if (strcmp(argv[1], "set") == 0) {
				NSString *preferenceName = [NSString stringWithFormat:@"LAEventListener-%s", argv[2]];
				[prefs setObject:[NSString stringWithUTF8String:argv[3]] forKey:preferenceName];
				SavePreferences(prefs);
				return 0;
			}
			break;
	}
	printf("Usage:\n\tactivator-config set [event] [listener]\n\t assigns an event to a listener\n\tactivator-config set [event]\n\t removes the listener assigned to an event\n\tactivator-config clear-events [listener]\n\t removes all events assigned to a listener\n");
	return 0;
}