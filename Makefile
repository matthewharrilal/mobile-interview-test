.PHONY: setup build test clean

setup:
	xcodegen generate && open ResortPass.xcodeproj

build:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination 'platform=iOS Simulator,name=iPhone 15' build

test:
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass -destination 'platform=iOS Simulator,name=iPhone 15' test

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/ResortPass-*
	xcodebuild -project ResortPass.xcodeproj -scheme ResortPass clean
