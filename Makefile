# ResortPass — local dev shortcuts.
# Canonical sim: iPhone 16 Pro / iOS 18 (matches CI + Maestro flows).
# If iOS 18.0 isn't installed locally, Xcode picks the nearest available iOS 18.x
# automatically — but it MUST be iOS 18 (Maestro flows fail on iOS 26 due to a
# known driver incompatibility; CI pins iPhone 16 Pro / iOS 18 for the same reason).

.PHONY: setup build test clean lint-animation lint

SIM_NAME = iPhone 16 Pro
SIM_OS = 18.0
DESTINATION = platform=iOS Simulator,name=$(SIM_NAME),OS=$(SIM_OS)

setup:
	xcodegen generate && open ResortPass.xcodeproj

build:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination '$(DESTINATION)' build

test:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination '$(DESTINATION)' test

# Preventive grep-gate: fails if any View .animation(...) call lacks `value:`.
# See scripts/README-lint-animation-binding.md for rationale.
lint-animation:
	bash scripts/lint-animation-binding.sh

lint: lint-animation

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/ResortPass-*
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass clean
