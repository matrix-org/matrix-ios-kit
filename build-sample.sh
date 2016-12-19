#!/bin/sh

# Clean the Xcode build folder to avoid caching issues that happens sometimes
rm -rf ~/Library/Developer/Xcode/DerivedData/*

pod update
xcodebuild -workspace MatrixKit.xcworkspace -scheme MatrixKitSample -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
