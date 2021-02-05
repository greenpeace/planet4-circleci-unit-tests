SHELL := /bin/bash

# File suffixes
BATS := bats
TAP := tap
XML := xml
OUT := out

# Output directory
LOGS := logs/$(TESTVERSION)

# Used in .env.bash
export LOGS
export OUT

# BATS test files
TEST_FILES := $(wildcard *.$(BATS))

# TAP output
TAP_FILES := $(patsubst %.$(BATS), $(LOGS)/%.$(TAP), $(TEST_FILES))

# XUNIT output
XML_DIRS := $(patsubst %.$(BATS), $(LOGS)/%/, $(TEST_FILES))

.PHONY: all clean tap xml

all: clean $(LOGS) $(XML_DIRS) $(TAP_FILES) status

clean:
ifndef LOGS
$(error LOGS is not set. Cowardly refusing to rm -fr an empty string)
endif
		@rm -fr $(LOGS)/

status:
		@echo 'ok'
		@! ag 'not ok' $(LOGS)/

tap: $(LOGS)/%.$(TAP)

xml: $(LOGS)/%/results.$(XML)

$(LOGS):
		@mkdir -p $(XML_DIRS)

$(LOGS)/%.$(TAP): %.$(BATS)
		-@OUT=$(OUT) bats --tap $^ | tee $@

$(LOGS)/%/results.$(XML): $(LOGS)/%.$(TAP)
		@tap-xunit --package="p4.ci.codeception.$(shell echo $@ | cut -d/ -f2 | cut -d. -f1 )" < $^ > $@
