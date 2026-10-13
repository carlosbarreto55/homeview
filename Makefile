# Command-line builds use the full Xcode without changing the system's
# active developer directory (no `sudo xcode-select` needed).
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

PROJECT     := HomeView.xcodeproj
SCHEME      := HomeView
DERIVED     := DerivedData
DESTINATION := platform=macOS
APP         := $(DERIVED)/Build/Products/Debug/HomeView.app
XCODEBUILD  := xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
               -destination '$(DESTINATION)' -derivedDataPath $(DERIVED)

.PHONY: generate build test run clean

generate:
	xcodegen generate

$(PROJECT): project.yml
	xcodegen generate

build: $(PROJECT)
	$(XCODEBUILD) build

test: $(PROJECT)
	$(XCODEBUILD) test

run: build
	-pkill -x HomeView
	open $(APP)

clean:
	rm -rf $(DERIVED) $(PROJECT)
