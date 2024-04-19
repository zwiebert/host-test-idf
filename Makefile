.PHONY: clean all test rebuild http_data print-help



default: help

clean : esp32-test-clean esp32-fullclean


help:
	@less test/make_help.txt


V ?= 0

ifneq "$(V)" "0"
esp32_build_opts += -v
endif


THIS_ROOT := $(realpath .)
BUILD_BASE ?= $(THIS_ROOT)/test/build/$(flavor)
esp32_build_dir := $(BUILD_BASE)
esp32_src_dir := $(THIS_ROOT)/test/$(flavor)
tmp_build_dir := /tmp/tronferno-mcu/build



host-test-all:
	@echo "No testing supported"


############# Doxygen ###################
doxy_flavors=usr dev api
DOXY_BUILD_PATH=$(THIS_ROOT)/doxy/build
DOXYFILE_PATH=$(THIS_ROOT)/doxy
include doxygen_rules.mk

$(DOXY_BUILD_PATH)/usr/input_files: $(DOXY_BUILD_PATH)/usr FORCE
	mkdir -p $(dir $@)
	echo "" > $@

$(DOXY_BUILD_PATH)/api/input_files: $(DOXY_BUILD_PATH)/api FORCE
	git ls-files '*.h' '*.hh' '*.md' | fgrep -e include -e README.md  > $@

$(DOXY_BUILD_PATH)/dev/input_files: $(DOXY_BUILD_PATH)/dev FORCE
	git ls-files '*.h' '*.c' '*.hh' '*.cc' '*.cpp' '*.md'  > $@

