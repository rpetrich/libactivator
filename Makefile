ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init --recursive
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

LIBRARY_NAME = libactivator Settings SpringBoard

# libactivator.dylib (/usr/lib)
ifeq ($(SINGLE),1)
	libactivator_FILES = single_libactivator.xi
else
	libactivator_FILES = LAEvent.m LARemoteListener.m LAListener.m libactivator.x LAEventDataSource.m EverywhereHooks.x LASettingsViewControllers.m
endif
libactivator_FRAMEWORKS = UIKit CoreGraphics QuartzCore
libactivator_PRIVATE_FRAMEWORKS = AppSupport GraphicsServices SpringBoardServices

# Settings.dylib (/Library/Activator)
ifeq ($(SINGLE),1)
	Settings_FILES = single_Settings.m
else
	Settings_FILES = LAListenerSettingsViewController.m LASettingsViewController.m LAWebSettingsController.m LARootSettingsController.m LAModeSettingsController.m LAEventSettingsController.m LAEventGroupSettingsController.m LAMenuSettingsController.m LAMenuItemsController.m LAMenuListenerSelectionController.m ActivatorEventViewHeader.m LAListenerTableViewDataSource.m LABlacklistSettingsController.m
endif
Settings_INSTALL_PATH = /Library/Activator
Settings_FRAMEWORKS = UIKit CoreGraphics QuartzCore
Settings_LDFLAGS = -L$(FW_OBJ_DIR) -lactivator

# SpringBoard.dylib (/Library/Activator)
ifeq ($(SINGLE),1)
	SpringBoard_FILES = single_SpringBoard.xi
else
	SpringBoard_FILES = Events.x SlideEvents.x LASimpleListener.x LAApplicationListener.x LAToggleListener.m LASpringBoardActivator.x LAMenuListener.m LADefaultEventDataSource.m
endif
SpringBoard_INSTALL_PATH = /Library/Activator
SpringBoard_FRAMEWORKS = UIKit CoreGraphics QuartzCore
SpringBoard_PRIVATE_FRAMEWORKS = AppSupport GraphicsServices
SpringBoard_LDFLAGS = -L$(FW_OBJ_DIR) -lactivator

# LibActivator.bundle (/System/Library/PreferenceBundles)
BUNDLE_NAME = LibActivator
LibActivator_FILES = Preferences.m
LibActivator_INSTALL_PATH = /System/Library/PreferenceBundles
LibActivator_FRAMEWORKS = UIKit CoreGraphics QuartzCore
LibActivator_PRIVATE_FRAMEWORKS = Preferences
LibActivator_LDFLAGS = -L$(FW_OBJ_DIR) -lactivator

# Activator.app (/Applications)
APPLICATION_NAME = Activator
Activator_FILES = Activator.m
Activator_LDFLAGS = -L$(FW_OBJ_DIR) -lactivator

ADDITIONAL_CFLAGS = -std=c99 -fomit-frame-pointer
OPTFLAG = -Os
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0

ifeq ($(SINGLE),1)
	ADDITIONAL_CFLAGS += -DSINGLE
endif

ifeq ($(PROFILING),1)
	ADDITIONAL_CFLAGS += -DCHEnableProfiling
endif

ifeq ($(DEBUG),1)
	ADDITIONAL_CFLAGS += -DCHDebug
endif

LOCALIZATION_PROJECT_NAME = libactivator
LOCALIZATION_DEST_PATH = /Library/Activator

TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0

include framework/makefiles/common.mk
include framework/makefiles/library.mk
include framework/makefiles/bundle.mk
include framework/makefiles/application.mk
include Localization/makefiles/common.mk

internal-stage::
	mkdir -p $(THEOS_STAGING_DIR)/usr/include/libactivator
	mkdir -p $(THEOS_STAGING_DIR)/Library/Activator/Listeners
	$(ECHO_NOTHING)rsync -a ./libactivator.h $(THEOS_STAGING_DIR)/usr/include/libactivator $(FW_RSYNC_EXCLUDES)$(ECHO_END)
	$(ECHO_NOTHING)rsync -a ./LICENSE $(THEOS_STAGING_DIR)/Library/Activator $(FW_RSYNC_EXCLUDES)$(ECHO_END)
	./coalesce_info_plists.sh "$(THEOS_STAGING_DIR)/Library/Activator/Listeners/" > "$(THEOS_STAGING_DIR)/Library/Activator/Listeners/bundled.plist"
	- find $(THEOS_STAGING_DIR) -iname '*.plist' -or -iname '*.strings' -exec plutil -convert binary1 {} \;

internal-after-install::
	install.exec "respring || killall -9 SpringBoard"

stage::
	$(ECHO_NOTHING)./symlink_localizations.sh "$(FW_PROJECT_DIR)/Localization/$(LOCALIZATION_PROJECT_NAME)" "$(LOCALIZATION_DEST_PATH)" "$(FW_STAGING_DIR)/Applications/Activator.app"$(ECHO_END)

endif

.PHONY: printvars
printvars:
	@$(foreach V,$(sort $(.VARIABLES)),$(if $(filter-out environment% default automatic,$(origin $V)),$(warning $V=$($V) ($(value $V)))))
