SHELL := /bin/bash

IMAGE_NAME := p4-unit-tests
BUILD_NAMESPACE ?= gcr.io
GOOGLE_PROJECT_ID ?= planet-4-151612

BUILD_IMAGE := $(BUILD_NAMESPACE)/$(GOOGLE_PROJECT_ID)/$(IMAGE_NAME)
export BUILD_IMAGE

BASE_IMAGE_NAME ?= circleci/php
BASE_IMAGE_VERSION ?= 7.0
export BASE_IMAGE_NAME

BASE_IMAGE := $(BASE_IMAGE_NAME):$(BASE_IMAGE_VERSION)
export BASE_IMAGE

MAINTAINER_NAME 	?= Raymond Walker
MAINTAINER_EMAIL 	?= raymond.walker@greenpeace.org

AUTHOR := $(MAINTAINER_NAME) <$(MAINTAINER_EMAIL)>
export AUTHOR

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

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)
VERSIONS := $(shell find php/* -type d | sed s/php\\///g )
export VERSIONS

# ============================================================================

all: init clean build test push

init:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

clean:
	rm -f php/7.0/Dockerfile php/7.1/Dockerfile php/7.2/Dockerfile

lint: lint-yaml lint-docker lint-ci

lint-yaml:
ifndef YAMLLINT
$(error "yamllint is not installed: https://github.com/adrienverge/yamllint")
endif
	@find . -type f -name '*.yml' | xargs yamllint

lint-docker: Dockerfile
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	@docker run --rm -i hadolint/hadolint < php/7.0/Dockerfile >/dev/null
	@docker run --rm -i hadolint/hadolint < php/7.1/Dockerfile >/dev/null
	@docker run --rm -i hadolint/hadolint < php/7.2/Dockerfile >/dev/null

lint-ci:
ifndef CIRCLECI
$(error "circleci is not installed: https://circleci.com/docs/2.0/local-cli/#installation")
endif
	@circleci config validate >/dev/null

pull:
	docker pull $(BASE_IMAGE)

Dockerfile:
	envsubst '$${BASE_IMAGE_NAME},$${AUTHOR}' < php/7.0/Dockerfile.in > php/7.0/$@
	envsubst '$${BASE_IMAGE_NAME},$${AUTHOR}' < php/7.1/Dockerfile.in > php/7.1/$@
	envsubst '$${BASE_IMAGE_NAME},$${AUTHOR}' < php/7.2/Dockerfile.in > php/7.2/$@

build:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	$(MAKE) -j lint pull
	for v in $(VERSIONS); do \
		docker build  \
			--tag=$(BUILD_IMAGE):php$${v}-$(BUILD_TAG) \
			--tag=$(BUILD_IMAGE):php$${v}-$(BUILD_NUM) \
			--tag=$(BUILD_IMAGE):php$${v}-$(REVISION_TAG) \
			php/$${v}/ ; \
	done

.PHONY: test
test:
	for v in $(VERSIONS); do \
		$(MAKE) -C $@ clean; \
		$(MAKE) TESTVERSION=$$v -k -C $@; \
		$(MAKE) -C $@ status; \
	done

push: push-tag

push-tag:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	docker push $(BUILD_IMAGE):php7.0-$(BUILD_TAG)
	docker push $(BUILD_IMAGE):php7.0-$(BUILD_NUM)
	docker push $(BUILD_IMAGE):php7.1-$(BUILD_TAG)
	docker push $(BUILD_IMAGE):php7.1-$(BUILD_NUM)
	docker push $(BUILD_IMAGE):php7.2-$(BUILD_TAG)
	docker push $(BUILD_IMAGE):php7.2-$(BUILD_NUM)

#TODO fix push-latest
push-latest:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	if [[ "$(PUSH_LATEST)" = "true" ]]; then { \
		docker tag $(BUILD_IMAGE):php7.0-$(REVISION_TAG) $(BUILD_IMAGE):latest; \
		docker push $(BUILD_IMAGE):latest; \
		for v in $(VERSIONS); do \
			docker tag $(BUILD_IMAGE):php$${v}-$(REVISION_TAG) $(BUILD_IMAGE):php$${v}; \
			docker push $(BUILD_IMAGE):php$${v}; \
		done \
	}	else { \
		echo "Not tagged.. skipping latest"; \
	} fi
