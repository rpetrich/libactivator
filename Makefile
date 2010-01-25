LIBRARY_NAME = libactivator
libactivator_OBJC_FILES = Actions.m Events.m ListenerSettingsViewController.m libactivator.m
libactivator_FRAMEWORKS = UIKit CoreGraphics
libactivator_PRIVATE_FRAMEWORKS = AppSupport GraphicsServices

BUNDLE_NAME = LibActivator
LibActivator_OBJC_FILES = Preferences.m
LibActivator_INSTALL_PATH = /System/Library/PreferenceBundles
LibActivator_FRAMEWORKS = UIKit CoreGraphics
LibActivator_PRIVATE_FRAMEWORKS = Preferences
LibActivator_LDFLAGS = -L$(FW_OBJ_DIR) -lactivator

GO_EASY_ON_ME = 1
ADDITIONAL_CFLAGS = -Wno-unused -Wno-switch -include Common.h
include framework/makefiles/common.mk
include framework/makefiles/library.mk
include framework/makefiles/bundle.mk

before-all:: Common.h

Common.h:
	echo "#define kPackageName \"$(shell grep ^Package: layout/DEBIAN/control | cut -d ' ' -f 2)\"" > Common.h
	echo "#define kPackageVersion \"$(shell grep ^Version: layout/DEBIAN/control | cut -d ' ' -f 2)\"" >> Common.h
