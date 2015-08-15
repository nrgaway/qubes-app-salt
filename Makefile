VERSION := $(shell cat version)

.PHONY: all
all:
	@true

.PHONY: get-sources
get-sources:
	git submodule init
	git submodule update

.PHONY: verify-sources
verify-sources:
	@true
