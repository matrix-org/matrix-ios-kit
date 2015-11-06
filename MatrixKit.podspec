Pod::Spec.new do |s|

  s.name         = "MatrixKit"
  s.version      = "0.2.5"
  s.summary      = "The Matrix reusable UI library for iOS based on MatrixSDK."

  s.description  = <<-DESC
					Matrix Kit provides basic reusable interfaces to ease building of apps compatible with Matrix (http://www.matrix.org).
                   DESC

  s.homepage     = "http://www.matrix.org"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.author             = { "matrix.org" => "support@matrix.org" }
  s.social_media_url   = "http://twitter.com/matrixdotorg"

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/matrix-org/matrix-ios-kit.git", :tag => "v0.2.5" }
  s.source_files  = "MatrixKit", "MatrixKit/**/*.{h,m}"
  s.resources	 = "MatrixKit/**/*.{xib}", "MatrixKit/Assets/MatrixKitAssets.bundle"
  
  s.requires_arc  = true

  s.dependency 'MatrixSDK', '~> 0.5.3'
  s.dependency 'HPGrowingTextView', '~> 1.1'
  s.dependency 'libPhoneNumber-iOS', '~> 0.7.6'

end
