# Simple project automation for AppleCheck

SCHEME ?= AppleCheck
PROJECT ?= AppleCheck.xcodeproj
CONFIG  ?= Debug

# Default destination builds for Simulator; override for device:
#   make build DESTINATION='generic/platform=iOS'
DESTINATION ?= platform=iOS\ Simulator,name=iPhone 15

.PHONY: all icons gen build clean xcinfo

all: icons gen build ## Generate icons, regenerate project, and build

xcinfo:
	@xcodebuild -version

icons:
	@echo "[icons] Generating AppIcon PNGs if source SVG present..."
	@if [ -f Assets.xcassets/AppIcon.appiconset/AppIcon.svg ]; then \
		bash Assets.xcassets/AppIcon.appiconset/generate-icons.sh; \
	else \
		echo "[icons] Skipping: Assets.xcassets/AppIcon.appiconset/AppIcon.svg not found."; \
	fi

gen:
	@echo "[gen] Regenerating Xcode project from project.yml..."
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "XcodeGen not found. Install with: brew install xcodegen"; \
		exit 2; \
	}
	@xcodegen generate

build:
	@echo "[build] Building $(SCHEME) ($(CONFIG)) for $(DESTINATION)..."
	@set -e; \
	if command -v xcpretty >/dev/null 2>&1; then \
		xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIG)" -destination '$(DESTINATION)' build | xcpretty; \
	else \
		xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIG)" -destination '$(DESTINATION)' build; \
	fi

clean:
	@echo "[clean] Cleaning build artifacts..."
	@xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIG)" clean >/dev/null

