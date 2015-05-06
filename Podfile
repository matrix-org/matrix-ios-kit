# Uncomment this line to define a global platform for your project
# platform :ios, "6.0"

source 'https://github.com/CocoaPods/Specs.git'

target "MatrixKitSample" do


# Different flavours of pods to Matrix SDK
# The tagged version on which this version of MatrixKit has been built
#pod 'MatrixSDK', '~> 0.4.0'

# The lastest release available on the CocoaPods repository 
#pod 'MatrixSDK'

# The develop branch version
pod 'MatrixSDK', :git => 'https://github.com/matrix-org/matrix-ios-sdk.git', :branch => 'voip'

# The one used for developping both MatrixSDK and MatrixKit
# Note that MatrixSDK must be cloned into a folder called matrix-ios-sdk next to the MatrixKit folder
#pod 'MatrixSDK', :path => '../matrix-ios-sdk/MatrixSDK.podspec'


pod 'HPGrowingTextView', '~> 1.1'
pod 'JSQMessagesViewController', '~> 7.0.0'

# There is no pod for OpenWebRTC-SDK. It must be git-cloned locally
# See: https://github.com/EricssonResearch/openwebrtc-ios-sdk#usage
# As of 2015/05/06, checkout the master branch of the `openwebrtc-ios-sdk` repo
pod 'OpenWebRTC-SDK', :path => '../openwebrtc-ios-sdk/OpenWebRTC-SDK.podspec'

end

target "MatrixKitSample" do

end

