OBJECTS=libactivator.o Events.o
TARGET=fs/usr/lib/libactivator.dylib

PREFS_OBJECTS=Preferences.o
PREFS_TARGET=fs/System/Library/PreferenceBundles/LibActivator.bundle/LibActivator

export NEXT_ROOT=/var/sdk

COMPILER=arm-apple-darwin9-gcc

LDFLAGS= \
		-Wall -Werror \
		-Z \
		-F/var/sdk/System/Library/Frameworks \
		-F/var/sdk/System/Library/PrivateFrameworks \
		-L/var/sdk/lib \
		-L/var/sdk/usr/lib \
		-L/usr/lib \
		-framework CoreFoundation -framework Foundation -framework UIKit \
		-lobjc

CFLAGS= -I/var/root/Headers -I/var/sdk/include -I/var/include \
		-fno-common \
		-g0 -O2 \
		-std=c99 \
		-include Common.h \
		-mcpu=arm1176jzf-s
		
ifeq ($(PROFILING),1)
		CFLAGS += -DCHEnableProfiling
endif

ifeq ($(DEBUG),1)
		CFLAGS += -DCHDebug
endif

all:	install

clean:
		rm -f $(OBJECTS) $(TARGET) $(PREFS_OBJECTS) $(PREFS_TARGET) Common.h
		rm -rf package
		find . -name '.svn' -prune -o -name '.git' -prune -o -name '._*' -delete -or -name '.DS_Store' -delete

Common.h:
		echo "#define kPackageName \"$(shell grep ^Package: control | cut -d ' ' -f 2)\"" > Common.h
		echo "#define kPackageVersion \"$(shell grep ^Version: control | cut -d ' ' -f 2)\"" >> Common.h

%.o:	%.m Common.h
		$(COMPILER) -c $(CFLAGS) $(filter %.m,$^) -o $@

$(TARGET): $(OBJECTS)
		$(COMPILER) $(LDFLAGS) -dynamiclib -o $@ $^
		ldid -S $@
				
$(PREFS_TARGET): $(PREFS_OBJECTS)
		$(COMPILER) $(LDFLAGS) -framework Preferences -bundle -o $@ $^
		ldid -S $@
				
package: $(TARGET) $(PREFS_TARGET) control
		rm -rf package
		mkdir -p package/DEBIAN
		cp -a control preinst prerm package/DEBIAN
		cp -a fs/* package
		cp -a libactivator.h package/usr/include/libactivator/
		- plutil -convert binary1 package/Library/MobileSubstrate/DynamicLibraries/Activator.plist
		dpkg-deb -b package $(shell grep ^Package: control | cut -d ' ' -f 2)_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb
		
install: package
		dpkg -i $(shell grep ^Package: control | cut -d ' ' -f 2)_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb
		# respring

zip:	clean
		- rm -rf ../$(shell grep ^Package: control | cut -d ' ' -f 2).tgz
		tar -cf ../$(shell grep ^Package: control | cut -d ' ' -f 2).tgz ./
