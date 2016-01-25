#!/bin/sh

pod update
xcodebuild -workspace MatrixKit.xcworkspace -scheme MatrixKitSample -configuration Release
