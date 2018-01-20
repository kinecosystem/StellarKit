Pod::Spec.new do |s|
  s.name        = "StellarKinKit"
  s.version     = "0.1.0"
  s.license     = { :type => "MIT" }
  s.homepage    = "https://github.com/marketplacer/keychain-swift"
  s.summary     = "StellarKinKit StellarKinKit StellarKinKit StellarKinKit"
  s.description = <<-DESC
                StellarKinKit StellarKinKit StellarKinKit StellarKinKit StellarKinKit
                DESC
  s.author      = { 'Kin Foundation' => 'kin@kik.com' }
  s.source      = { :git => "https://github.com/kinfoundation/StellarKinKit.git", :tag => s.version, :submodules => true }
  s.source_files =
  s.ios.deployment_target = "8.0"

  s.preserve_paths = 'swift-sodium/Sodium/libsodium/module.modulemap', 'swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.source_files = 'StellarKinKit/source/*.swift', 'swift-sodium/Sodium/*.{swift,h}', 'swift-sodium/Sodium/libsodium/*.h', 'keychain-swift/KeychainSwift/*.swift'
  s.vendored_library    = 'swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.private_header_files = 'swift-sodium/Sodium/libsodium/*.h'

  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/swift-sodium/Sodium/libsodium',
    'OTHER_LDFLAGS' => '-lsodium-ios',
    'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/swift-sodium/Sodium/libsodium'
  }

end
