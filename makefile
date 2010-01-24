OBJECTS=libactivator.o Events.o ListenerSettingsViewController.o Actions.o
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
		-framework CoreFoundation -framework Foundation -framework UIKit -framework CoreGraphics -framework GraphicsServices -framework AppSupport \
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
		mkdir -p fs/usr/lib
		$(COMPILER) $(LDFLAGS) -dynamiclib -install_name /usr/lib/libactivator.dylib -o $@ $^
		ldid -S $@
				
$(PREFS_TARGET): $(PREFS_OBJECTS) $(TARGET)
		mkdir -p fs/System/Library/PreferenceBundles/LibActivator.bundle/
		$(COMPILER) -L./fs/usr/lib $(LDFLAGS) -lactivator -framework Preferences -bundle -o $@ $(filter %.o,$^)
		ldid -S $@
				
package: $(TARGET) $(PREFS_TARGET) control
		rm -rf package
		mkdir -p package/DEBIAN
		mkdir -p package/usr/include/libactivator
		mkdir -p package/Library/Activator/Listeners
		cp -a control postinst package/DEBIAN
		cp -a fs/* package
		cp -a libactivator.h package/usr/include/libactivator/
		- plutil -convert binary1 package/Library/MobileSubstrate/DynamicLibraries/Activator.plist
		- plutil -convert binary1 package/Library/Activator/Info.plist
		- plutil -convert binary1 package/Library/Activator/en.lproj/Localizable.strings
		- plutil -convert binary1 package/Library/Activator/it.lproj/Localizable.strings
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.lock.hold.short/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.lock.press.double/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.menu.hold.short/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.menu.press.at-springboard/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.menu.press.double/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.menu.press.single/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.motion.shake/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.slide-in.bottom/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.slide-in.bottom-left/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.slide-in.bottom-right/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.springboard.pinch/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.springboard.spread/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.statusbar.hold/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.statusbar.swipe.down/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.statusbar.swipe.left/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.statusbar.swipe.right/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.statusbar.tap.double/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.volume.display-tap/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.volume.down-up/Info.plist
		- plutil -convert binary1 package/Library/Activator/Events/libactivator.volume.up-down/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.homebutton/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.powerdown/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.reboot/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.respring/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.safemode/Info.plist
		- plutil -convert binary1 package/Library/Activator/Listeners/libactivator.system.sleepbutton/Info.plist
		- plutil -convert binary1 package/Library/PreferenceLoader/Preferences/LibActivator.plist
		- plutil -convert binary1 package/System/Library/PreferenceBundles/LibActivator.bundle/Info.plist
		dpkg-deb -b package $(shell grep ^Package: control | cut -d ' ' -f 2)_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb
		
install: package
		dpkg -i $(shell grep ^Package: control | cut -d ' ' -f 2)_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb

respring: install
		respring

zip:	clean
		- rm -rf ../$(shell grep ^Package: control | cut -d ' ' -f 2).tgz
		tar -cf ../$(shell grep ^Package: control | cut -d ' ' -f 2).tgz ./
