# Uncomment this line to define a global platform for your project
platform :ios, '9.0'

# Use frameforks to allow usage of pod written in Swift (like PiwikTracker)
use_frameworks!

abstract_target 'MatrixKitSamplePods' do
    
    # Different flavours of pods to Matrix SDK
    # The tagged version on which this version of MatrixKit has been built
    pod 'MatrixSDK', '= 0.18.4'
    
    # The lastest release available on the CocoaPods repository
    #pod 'MatrixSDK'
    
    # The develop branch version
    #pod 'MatrixSDK', :git => 'https://github.com/matrix-org/matrix-ios-sdk.git', :branch => 'develop'
    
    # The one used for developping both MatrixSDK and MatrixKit
    # Note that MatrixSDK must be cloned into a folder called matrix-ios-sdk next to the MatrixKit folder
    #pod 'MatrixSDK', :path => '../matrix-ios-sdk/MatrixSDK.podspec'
    
    pod 'libPhoneNumber-iOS', '~> 0.9.13'
    pod 'HPGrowingTextView', '~> 1.1'
    pod 'JSQMessagesViewController', '~> 7.2.0'
    pod 'DTCoreText', '~> 1.6.21'
    pod 'Down', '~> 0.9.3'

        
    target "MatrixKitSample" do
        
    end
    
    target "MatrixKitTests" do
        
    end
    
end
