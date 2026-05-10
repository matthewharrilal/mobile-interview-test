.PHONY: setup build test clean lint-animation lint

setup:
	xcodegen generate && open ResortPass.xcodeproj

build:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination 'platform=iOS Simulator,name=iPhone 15' build

test:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination 'platform=iOS Simulator,name=iPhone 15' test

# Preventive grep-gate: fails if any View .animation(...) call lacks `value:`.
# See scripts/README-lint-animation-binding.md for rationale.
lint-animation:
	bash scripts/lint-animation-binding.sh

lint: lint-animation

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/ResortPass-*
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass clean
