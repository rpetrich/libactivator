ifeq ($(shell [ -f ./framework/makefiles/common.mk ] && echo 1 || echo 0),0)
all clean package install::
	git submodule update --init
	$(MAKE) $(MAKEFLAGS) MAKELEVEL=0 $@
else

# ExampleListener.dylib (/Library/MobileSubstrate/DynamicLibraries)
TWEAK_NAME = ExampleListener
ExampleListener_OBJC_FILES = ExampleListener.m
ExampleListener_FRAMEWORKS = Foundation UIKit
ExampleListener_LDFLAGS = -lactivator -L../obj

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

endif
