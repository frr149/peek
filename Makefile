# peek — Capture app and web UI screenshots without stealing focus
# https://github.com/frr149/peek

BINARY_NAME := peek
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
PREFIX := /usr/local
BUILD_DIR := .build/release
DIST_DIR := dist
GITHUB_REPO := frr149/peek
TAP_REPO := frr149/homebrew-tools

# ─── Build ────────────────────────────────────────────────────────────

.PHONY: build test install uninstall release gh-release bump-formula clean

build:
	swift build -c release

debug:
	swift build

test:
	swift test

run:
	swift run peek $(ARGS)

# ─── Install ──────────────────────────────────────────────────────────

install: build
	install -d $(PREFIX)/bin
	install -m 755 $(BUILD_DIR)/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME)
	@echo "✓ Installed $(BINARY_NAME) to $(PREFIX)/bin/"

uninstall:
	rm -f $(PREFIX)/bin/$(BINARY_NAME)
	@echo "✓ Removed $(BINARY_NAME) from $(PREFIX)/bin/"

# ─── Release ──────────────────────────────────────────────────────────

universal:
	swift build -c release --arch arm64 --arch x86_64

release: universal
	@if [ "$(VERSION)" = "dev" ]; then echo "Error: no git tag found. Tag first: git tag v0.1.0"; exit 1; fi
	mkdir -p $(DIST_DIR)
	cp .build/apple/Products/Release/$(BINARY_NAME) $(DIST_DIR)/$(BINARY_NAME)
	cd $(DIST_DIR) && tar -czf $(BINARY_NAME)-$(VERSION)-macos.tar.gz $(BINARY_NAME)
	@echo ""
	@echo "── Release artifact ──"
	@echo "File: $(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz"
	@echo "SHA256: $$(shasum -a 256 $(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz | cut -d' ' -f1)"

gh-release: release
	gh release create $(VERSION) $(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz \
		--repo $(GITHUB_REPO) \
		--title "$(VERSION)" \
		--generate-notes

# ─── Homebrew ─────────────────────────────────────────────────────────

formula: release
	@SHA=$$(shasum -a 256 $(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz | cut -d' ' -f1); \
	echo 'class Peek < Formula'; \
	echo '  desc "Capture app and web UI screenshots without stealing focus"'; \
	echo '  homepage "https://github.com/$(GITHUB_REPO)"'; \
	echo '  url "https://github.com/$(GITHUB_REPO)/releases/download/$(VERSION)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz"'; \
	echo "  sha256 \"$$SHA\""; \
	echo '  license "MIT"'; \
	echo ''; \
	echo '  depends_on :macos'; \
	echo ''; \
	echo '  def install'; \
	echo '    bin.install "$(BINARY_NAME)"'; \
	echo '  end'; \
	echo ''; \
	echo '  test do'; \
	echo '    assert_match "peek", shell_output("#{bin}/peek --version")'; \
	echo '  end'; \
	echo 'end'

bump-formula: release
	@SHA=$$(shasum -a 256 $(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-macos.tar.gz | cut -d' ' -f1); \
	echo "TODO: update $(TAP_REPO) with version=$(VERSION) sha256=$$SHA"
	@echo "Run: gh repo clone $(TAP_REPO) /tmp/tap && update Formula/peek.rb && push"

# ─── Housekeeping ─────────────────────────────────────────────────────

clean:
	swift package clean
	rm -rf $(DIST_DIR)

loc:
	@find Sources Tests -name '*.swift' | xargs wc -l | tail -1

help:
	@echo "Usage:"
	@echo "  make build        Build release binary"
	@echo "  make debug        Build debug binary"
	@echo "  make test         Run tests"
	@echo "  make run ARGS=..  Run with arguments"
	@echo "  make install      Install to /usr/local/bin"
	@echo "  make uninstall    Remove from /usr/local/bin"
	@echo "  make universal    Build universal (arm64+x86_64)"
	@echo "  make release      Build universal + create tarball"
	@echo "  make gh-release   Create GitHub release with tarball"
	@echo "  make formula      Print Homebrew formula to stdout"
	@echo "  make bump-formula Update Homebrew tap"
	@echo "  make clean        Remove build artifacts"
	@echo "  make loc          Count lines of code"
