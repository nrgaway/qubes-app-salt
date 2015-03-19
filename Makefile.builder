ifeq ($(PACKAGE_SET),dom0)
  RPM_SPEC_FILES := rpm_spec/salt.spec

else ifeq ($(PACKAGE_SET),vm)
  ifneq ($(filter $(DISTRIBUTION), debian),)
    DEBIAN_BUILD_DIRS := debian.master/debian
    SOURCE_COPY_IN := source-debian-quilt-copy-in
  else ifneq ($(filter $(DISTRIBUTION), qubuntu),)
    DEBIAN_BUILD_DIRS := debian-vm/debian
    SOURCE_COPY_IN := source-debian-quilt-copy-in
  endif

  RPM_SPEC_FILES := rpm_spec/salt.spec
endif

source-debian-quilt-copy-in: DEBIAN = $(DEBIAN_BUILD_DIRS)/..
source-debian-quilt-copy-in: VERSION = $(shell $(DEBIAN_PARSER) changelog --package-version $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog)
source-debian-quilt-copy-in: NAME = $(shell $(DEBIAN_PARSER) changelog --package-name $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog)
source-debian-quilt-copy-in: PACKAGE_TGZ = "$(CHROOT_DIR)/$(DIST_SRC)/$(NAME)-$(VERSION).tar.gz"
source-debian-quilt-copy-in: PACKAGE_ORIG_TGZ = "$(CHROOT_DIR)/$(DIST_SRC)/$(NAME)_$(VERSION).orig.tar.gz"
source-debian-quilt-copy-in:
	-$(shell $(ORIG_SRC)/debian-quilt $(ORIG_SRC)/series-debian.conf $(CHROOT_DIR)/$(DIST_SRC)/$(DEBIAN_BUILD_DIRS)/patches)
	cp -a $(PACKAGE_TGZ) $(PACKAGE_ORIG_TGZ)
	tar xfz $(PACKAGE_ORIG_TGZ) -C $(CHROOT_DIR)/$(DIST_SRC)/$(DEBIAN) --strip-components=1 

# vim: filetype=make
