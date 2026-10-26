.PHONY: generate build test archive

generate:
	xcodegen generate

build: generate
	xcodebuild -project OPhoneAI.xcodeproj -scheme OPhoneAI -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project OPhoneAI.xcodeproj -scheme OPhoneAI -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

archive: generate
	bash scripts/build-unsigned-ipa.sh
