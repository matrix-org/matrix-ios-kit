Pod::Spec.new do |s|

  s.name         = "MatrixKit"
  s.version      = "0.4.11"
  s.summary      = "The Matrix reusable UI library for iOS based on MatrixSDK."

  s.description  = <<-DESC
					Matrix Kit provides basic reusable interfaces to ease building of apps compatible with Matrix (https://www.matrix.org).
                   DESC

  s.homepage     = "https://www.matrix.org"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.author             = { "matrix.org" => "support@matrix.org" }
  s.social_media_url   = "http://twitter.com/matrixdotorg"

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/matrix-org/matrix-ios-kit.git", :tag => "v0.4.11" }
  s.source_files  = "MatrixKit", "MatrixKit/**/*.{h,m}"
  s.resources	 = "MatrixKit/**/*.{xib}"
  s.resource_bundles = { 'MatrixKit' => ['MatrixKit/Assets/MatrixKitAssets.bundle/**'] }

  s.requires_arc  = true

  s.dependency 'MatrixSDK', '0.7.11'
  s.dependency 'HPGrowingTextView', '~> 1.1'
  s.dependency 'libPhoneNumber-iOS', '~> 0.8.14'
  s.dependency 'DTCoreText', '~> 1.6.17'
  s.dependency 'cmark', '~> 0.24.1'

end
