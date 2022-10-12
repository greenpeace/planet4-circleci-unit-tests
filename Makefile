SHELL := /bin/bash

# ============================================================================

# Read default configuration
include config.default
export $(shell sed 's/=.*//' config.default)

# ============================================================================

IMAGE_NAME := p4-unit-tests
BUILD_NAMESPACE ?= greenpeaceinternational

BUILD_IMAGE := $(BUILD_NAMESPACE)/$(IMAGE_NAME)
export BUILD_IMAGE

# ============================================================================

SED_MATCH ?= [^a-zA-Z0-9._-]

ifeq ($(CIRCLECI),true)
# Configure build variables based on CircleCI environment vars
BUILD_NUM = build-$(CIRCLE_BUILD_NUM)
BRANCH_NAME ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_BRANCH)")
BUILD_TAG ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_TAG)")
else
# Not in CircleCI environment, try to set sane defaults
BUILD_NUM = build-$(shell uname -n | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9._-]/-/g')
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD | sed 's/$(SED_MATCH)/-/g')
BUILD_TAG ?= $(shell git tag -l --points-at HEAD | tail -n1 | sed 's/$(SED_MATCH)/-/g')
endif

# If BUILD_TAG is blank there's no tag on this commit
ifeq ($(strip $(BUILD_TAG)),)
# Default to branch name
BUILD_TAG := $(BRANCH_NAME)
else
# Consider this the new :latest image
# FIXME: implement build tests before tagging with :latest
PUSH_LATEST := true
endif

REVISION_TAG = $(shell git rev-parse --short HEAD)

# ============================================================================

# Check necessary commands exist

DOCKER := $(shell command -v docker 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)

# ============================================================================

all: init prepare build test push

init:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

lint: lint-yaml lint-docker

lint-yaml:
ifndef YAMLLINT
	$(error "yamllint is not installed: https://github.com/adrienverge/yamllint")
endif
	@find . -type f -name '*.yml' | xargs yamllint

lint-docker: Dockerfile
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	for v in $(PHP_VERSIONS); do \
		docker run --rm -i hadolint/hadolint < php/$${v}/Dockerfile ; \
	done
	docker run --rm -i hadolint/hadolint < node/Dockerfile

prepare: Dockerfile

Dockerfile:
	for v in $(PHP_VERSIONS); do \
		f=Dockerfile.php.in ; \
		mkdir -p php/$${v} ; \
		PHP_VERSION=$${v} envsubst \
			'$${PHP_IMAGE_NAME},$${PHP_VERSION}' \
			< $$f > php/$${v}/$@ ; \
	done
	mkdir -p node
	envsubst '$${NODE_IMAGE_NAME},$${NODE_VERSION},$${STYLELINT_VERSION},$${ESLINT_VERSION} \
		$${PA11Y_CI_VERSION},$${PA11Y_CI_REPORTER_HTML_VERSION}' \
		< Dockerfile.node.in > node/Dockerfile

build:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	$(MAKE) -j lint
	for v in $(PHP_VERSIONS); do \
		docker build \
			--tag=$(BUILD_IMAGE):php$${v}-$(BUILD_TAG) \
			--tag=$(BUILD_IMAGE):php$${v}-$(BUILD_NUM) \
			--tag=$(BUILD_IMAGE):php$${v}-$(REVISION_TAG) \
			php/$${v}/ ; \
	done
	docker build \
		--tag=$(BUILD_IMAGE):node${NODE_VERSION}-$(BUILD_TAG) \
		--tag=$(BUILD_IMAGE):node${NODE_VERSION}-$(BUILD_NUM) \
		--tag=$(BUILD_IMAGE):node${NODE_VERSION}-$(REVISION_TAG) \
		node/ ; \


.PHONY: test
test:
	@for v in $(PHP_VERSIONS); do \
		$(MAKE) TESTVERSION=$$v --no-print-directory -C $@ clean; \
		$(MAKE) TESTVERSION=$$v --no-print-directory -k -C $@; \
		$(MAKE) TESTVERSION=$$v --no-print-directory -C $@ status; \
	done

push: push-tag

push-tag:
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	for v in $(PHP_VERSIONS); do \
		docker push $(BUILD_IMAGE):php$${v}-$(BUILD_TAG); \
		docker push $(BUILD_IMAGE):php$${v}-$(BUILD_NUM); \
	done
	docker push $(BUILD_IMAGE):node${NODE_VERSION}-$(BUILD_TAG)
	docker push $(BUILD_IMAGE):node${NODE_VERSION}-$(BUILD_NUM)

push-latest:
ifndef DOCKER
	$(error "docker is not installed: https://docs.docker.com/install/")
endif
	if [[ "$(PUSH_LATEST)" = "true" ]]; then { \
		for v in $(PHP_VERSIONS); do \
			docker tag $(BUILD_IMAGE):php$${v}-$(REVISION_TAG) $(BUILD_IMAGE):php$${v}; \
			docker push $(BUILD_IMAGE):php$${v}; \
		done; \
		docker tag $(BUILD_IMAGE):node${NODE_VERSION}-$(REVISION_TAG) $(BUILD_IMAGE):node${NODE_VERSION}; \
		docker push $(BUILD_IMAGE):node${NODE_VERSION}; \
	}	else { \
		echo "Not tagged.. skipping latest"; \
	} fi
