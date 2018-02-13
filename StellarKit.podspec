Pod::Spec.new do |s|
  s.name        = "StellarKit"
  s.version     = "0.1.7"
  s.license     = { :type => "MIT" }
  s.homepage    = "https://github.com/kinfoundation/StellarKit.git"
  s.summary     = "A framework for communicating with a Stellar Horizon node"
  s.description = <<-DESC
		StellarKit implements a minimum set operations required to implement the KIN crypto-currency on top of Stellar.  Contributions to extend the repertoire of available operations will be considered.
                DESC
  s.author      = { 'Kin Foundation' => 'kin@kik.com' }
  s.source      = { :git => "https://github.com/kinfoundation/StellarKit.git", :tag => s.version, :submodules => true }

  s.ios.deployment_target = "8.0"

  s.preserve_paths        = 'StellarKit/third-party/swift-sodium/Sodium/libsodium/module.modulemap', 'StellarKit/third-party/swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.source_files          = 'StellarKit/source/**/*.swift', 'StellarKit/third-party/swift-sodium/Sodium/*.{swift,h}', 'StellarKit/third-party/swift-sodium/Sodium/libsodium/*.h', 'StellarKit/third-party/keychain-swift/KeychainSwift/*.swift', 'StellarKit/third-party/EventSource/EventSource/*.swift'
  s.vendored_library      = 'StellarKit/third-party/swift-sodium/Sodium/libsodium/libsodium-ios.a'
  s.private_header_files  = 'StellarKit/third-party/swift-sodium/Sodium/libsodium/*.h'

  s.pod_target_xcconfig   = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/StellarKit/third-party/swift-sodium/Sodium/libsodium',
    'OTHER_LDFLAGS' => '-lsodium-ios',
    'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/StellarKit/third-party/swift-sodium/Sodium/libsodium'
  }

end
