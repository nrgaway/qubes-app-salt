ifeq ($(PACKAGE_SET),dom0)
  RPM_SPEC_FILES := rpm_spec/salt.spec
  SOURCE_COPY_IN := source-copy-in-fedora-mgmt-salt-app-saltstack

else ifeq ($(PACKAGE_SET),vm)
  ifneq ($(filter $(DISTRIBUTION), debian qubuntu),)
    DEBIAN_BUILD_DIRS := debian.master/debian
    SOURCE_COPY_IN := source-copy-in-debian-mgmt-salt-app-saltstack
  else
    RPM_SPEC_FILES := rpm_spec/salt.spec
    SOURCE_COPY_IN := source-copy-in-fedora-mgmt-salt-app-saltstack
  endif
endif

source-copy-in-fedora-mgmt-salt-app-saltstack: VERSION = $(shell cat $(ORIG_SRC)/version)
source-copy-in-fedora-mgmt-salt-app-saltstack: NAME = salt
source-copy-in-fedora-mgmt-salt-app-saltstack: SRC_FILE = "$(CHROOT_DIR)/$(DIST_SRC)/$(NAME)-$(VERSION).tar.gz"
source-copy-in-fedora-mgmt-salt-app-saltstack:
	tar cfz $(SRC_FILE) --exclude-vcs -C $(CHROOT_DIR)/$(DIST_SRC)/salt .

source-copy-in-debian-mgmt-salt-app-saltstack: VERSION = $(shell cat $(ORIG_SRC)/version)
source-copy-in-debian-mgmt-salt-app-saltstack: NAME = $(shell $(DEBIAN_PARSER) changelog --package-name $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog)
source-copy-in-debian-mgmt-salt-app-saltstack: ORIG_FILE = "$(CHROOT_DIR)/$(DIST_SRC)/$(NAME)_$(VERSION).orig.tar.gz"
source-copy-in-debian-mgmt-salt-app-saltstack:
	-$(shell $(ORIG_SRC)/debian-quilt $(ORIG_SRC)/series-debian.conf $(CHROOT_DIR)/$(DIST_SRC)/$(DEBIAN_BUILD_DIRS)/patches)
	tar cfz $(ORIG_FILE) --exclude-vcs -C $(CHROOT_DIR)/$(DIST_SRC)/salt .
	cp -an $(CHROOT_DIR)/$(DIST_SRC)/salt/. $(CHROOT_DIR)/$(DIST_SRC)/debian.master

# vim: filetype=make
