Pod::Spec.new do |s|

  s.name         = "MatrixKit"
  s.version      = "0.12.12"
  s.summary      = "The Matrix reusable UI library for iOS based on MatrixSDK."

  s.description  = <<-DESC
					Matrix Kit provides basic reusable interfaces to ease building of apps compatible with Matrix (https://www.matrix.org).
                   DESC

  s.homepage     = "https://www.matrix.org"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.author             = { "matrix.org" => "support@matrix.org" }
  s.social_media_url   = "http://twitter.com/matrixdotorg"

  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/matrix-org/matrix-ios-kit.git", :tag => "v#{s.version}" }

  s.requires_arc  = true

  s.swift_version = '5.0'

  s.dependency 'MatrixSDK', "0.16.11"
  s.dependency 'HPGrowingTextView', '~> 1.1'
  s.dependency 'libPhoneNumber-iOS', '~> 0.9.13'
  s.dependency 'DTCoreText', '~> 1.6.23'
  s.dependency 'cmark', '~> 0.24.1'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |core|
    core.source_files  = "MatrixKit", "MatrixKit/**/*.{h,m,swift}", "Libs/**/*.{h,m,swift}"
    core.resources = ["MatrixKit/**/*.{xib}", "MatrixKit/Assets/MatrixKitAssets.bundle"]
    core.dependency 'DTCoreText'
  end

  s.subspec 'AppExtension' do |ext|
    ext.source_files  = "MatrixKit", "MatrixKit/**/*.{h,m,swift}", "Libs/**/*.{h,m,swift}"
    ext.resources = ["MatrixKit/**/*.{xib}", "MatrixKit/Assets/MatrixKitAssets.bundle"]
    ext.dependency 'DTCoreText/Extension'
  end

end
