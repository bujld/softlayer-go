GO_CMD=go
GO_BUILD=$(GO_CMD) build
GO_DEPS=$(GO_CMD) get -d -v
GO_DEPS_UPDATE=$(GO_DEPS) -u
GO_FMT=gofmt
GO_INSTALL=$(GO_CMD) install
GO_RUN=$(GO_CMD) run
GO_TEST=$(GO_CMD) test
TOOLS=$(GO_RUN) tools/*.go
VETARGS?=-all
COVERPROFILE=coverage.out

PACKAGE_LIST := $$(go list ./... | grep -v '/vendor/')

.PHONY: all alpha build deps fmt fmtcheck generate install release test coverage test_deps update_deps version vet

all: build

alpha:
	@$(TOOLS) version --bump patch --prerelease alpha
	git add sl/version.go
	git commit -m "Bump version"
	git push

build: fmtcheck vet deps
	$(GO_BUILD) ./...

deps:
	$(GO_DEPS) ./...

fmt:
	@$(GO_FMT) -w `find . -name '*.go' | grep -v vendor`

fmtcheck:
	@fmt_list=$$($(GO_FMT) -e -l `find . -name '*.go' | grep -v vendor`) && \
	[ -z $${fmt_list} ] || \
		(echo "gofmt needs to be run on the following files:" \
			&& echo "$${fmt_list}" && \
			echo "You can run 'make fmt' to format code" && false)

generate:
	@$(TOOLS) generate

install: fmtcheck deps
	@$(GO_INSTALL) ./...

release: build
	@NEW_VERSION=$$($(TOOLS) version --bump patch) && \
	git add sl/version.go && \
	git commit -m "Cut release $${NEW_VERSION}" && \
	git tag $${NEW_VERSION} && \
	git push && \
	git push origin $${NEW_VERSION}

test: fmtcheck vet test_deps
	@$(GO_TEST) $(PACKAGE_LIST) -timeout=30s -parallel=4

coverage:
	@echo "Running unit tests. Cover profile saved to $(COVERPROFILE) ...\n"
	@$(GO_TEST) $(PACKAGE_LIST) -timeout=30s -parallel=4 -coverprofile=$(COVERPROFILE)
	@echo "\nBuilding function coverage report...\n"
	@$(GO_CMD) tool cover -func=$(COVERPROFILE)

test_deps:
	$(GO_DEPS) -t ./...

update_deps:
	$(GO_DEPS_UPDATE) ./...

version:
	@$(TOOLS) version

# vet runs the Go source code static analysis tool `vet` to find
# any common errors.
vet:
	@go vet $(VETARGS) $$(go list ./... | grep -v datatypes) ; if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "Vet found suspicious constructs. Please check the reported constructs"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi
