fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios build_sample_app
```
fastlane ios build_sample_app
```
Build the demo app for simulator
### ios point_podspec_to_pending_releases
```
fastlane ios point_podspec_to_pending_releases
```
Modify the MatrixKit.podspec locally to point to the latest 'release/*/release' branch of 'MatrixSDK' if such one exists, or to develop otherwise
### ios point_podspec_to_same_feature
```
fastlane ios point_podspec_to_same_feature
```
Modify the MatrixKit.podspec locally to point to the same branch of 'MatrixSDK' as the current one if such one exists, or to develop otherwise
### ios point_sample_app_to_pending_releases
```
fastlane ios point_sample_app_to_pending_releases
```
Modify the Podfile of the sample app locally to point to the latest 'release/*/release' brnach of 'MatrixSDK' if such one exists, or to develop otherwise
### ios point_sample_app_to_same_feature
```
fastlane ios point_sample_app_to_same_feature
```
Modify the Podfile of the sample app locally to point to the same branch of 'MatrixSDK' as the current one if such one exists, or to develop otherwise

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
