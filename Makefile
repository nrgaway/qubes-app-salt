VERSION := $(shell cat version)

.PHONY: all
all:
	@true

help:
	@echo "make get-sources           -- submodule init and update"

.PHONY: get-sources
get-sources:
	git submodule init
	git submodule update

.PHONY: verify-sources
verify-sources:
	@true
