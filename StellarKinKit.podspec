Pod::Spec.new do |s|
  s.name        = "StellarKinKit"
  s.version     = "0.1.1"
  s.license     = { :type => "MIT" }
  s.homepage    = "http://www.kinecosystem.org/"
  s.summary     = "StellarKinKit StellarKinKit StellarKinKit StellarKinKit"
  s.description = <<-DESC
                StellarKinKit StellarKinKit StellarKinKit StellarKinKit StellarKinKit
                DESC
  s.author      = { 'Kin Foundation' => 'kin@kik.com' }
  s.source      = { :git => "https://github.com/kinfoundation/StellarKinKit.git", :tag => s.version, :submodules => true }

  s.ios.deployment_target = "8.0"

  s.preserve_paths        = 'StellarKinKit/third-party/swift-sodium/Sodium/libsodium/module.modulemap', 'StellarKinKit/third-party/swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.source_files          = 'StellarKinKit/source/*.swift', 'StellarKinKit/third-party/swift-sodium/Sodium/*.{swift,h}', 'StellarKinKit/third-party/swift-sodium/Sodium/libsodium/*.h', 'StellarKinKit/third-party/keychain-swift/KeychainSwift/*.swift'
  s.vendored_library      = 'StellarKinKit/third-party/swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.private_header_files  = 'StellarKinKit/third-party/swift-sodium/Sodium/libsodium/*.h'

  s.pod_target_xcconfig   = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/StellarKinKit/third-party/swift-sodium/Sodium/libsodium',
    'OTHER_LDFLAGS' => '-lsodium-ios',
    'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/StellarKinKit/third-party/swift-sodium/Sodium/libsodium'
  }

end
