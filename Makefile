RPMS_DIR=rpm/
VERSION := $(shell cat version)

all:
	@true

help:
	@echo "make all                   -- compile all binaries"
	@echo "make rpms-vm               -- generate binary rpm packages for VM"
	@echo "make rpms-dom0             -- generate binary rpm packages for Dom0"

rpms-dom0:
	PACKAGE_SET=dom0 rpmbuild --define "_rpmdir $(RPMS_DIR)" -bb rpm_spec/salt.spec

rpms-vm:
	PACKAGE_SET=vm rpmbuild --define "_rpmdir $(RPMS_DIR)" -bb rpm_spec/salt.spec

get-sources:
	git submodule init
	git submodule update

