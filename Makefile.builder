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

mgmt-salt-app-saltstack-update-version-info: 
	$(shell cd $(ORIG_SRC); git submodule init)
	$(shell cd $(ORIG_SRC); git submodule update)
	$(eval chroot_src = "$(CHROOT_DIR)/$(DIST_SRC)") 
	$(eval version = $(shell date +%Y.%m)) 
	$(eval release = $(shell date +%d~develop)) 
	$(shell rm -f $(chroot_src)/version) 
	$(shell rm -f $(chroot_src)/rel) 
	$(shell echo "$(version)" > $(chroot_src)/version) 
	$(shell echo "$(release)" > $(chroot_src)/rel) 

source-copy-in-fedora-mgmt-salt-app-saltstack: mgmt-salt-app-saltstack-update-version-info 
	$(eval name = salt) 
	$(eval src_file = "$(chroot_src)/$(name)-$(version).tar.gz") 
	$(shell tar cfz $(src_file) --exclude-vcs -C $(chroot_src)/$(name) .)

source-copy-in-debian-mgmt-salt-app-saltstack: mgmt-salt-app-saltstack-update-version-info
	$(shell rm -f $(chroot_src)/$(DEBIAN_BUILD_DIRS)/changelog) 
	$(shell cp -p $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog $(chroot_src)/$(DEBIAN_BUILD_DIRS))
	$(eval name = $(shell $(DEBIAN_PARSER) changelog --package-name $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog))
	$(eval name = $(shell $(DEBIAN_PARSER) changelog --package-name $(ORIG_SRC)/$(DEBIAN_BUILD_DIRS)/changelog))
	$(eval orig_file = "$(chroot_src)/$(name)_$(version).orig.tar.gz")
	-$(shell $(ORIG_SRC)/debian-quilt $(ORIG_SRC)/series-debian.conf $(chroot_src)/$(DEBIAN_BUILD_DIRS)/patches)
	$(shell tar cfz $(orig_file) --exclude-vcs -C $(chroot_src)/salt .)
	cp -an $(chroot_src)/salt/. $(chroot_src)/debian.master

# vim: filetype=make
