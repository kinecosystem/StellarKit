Pod::Spec.new do |s|
  s.name        = "StellarKinKit"
  s.version     = "0.0.2"
  s.license     = { :type => "MIT" }
  s.homepage    = "https://github.com/marketplacer/keychain-swift"
  s.summary     = "StellarKinKit StellarKinKit StellarKinKit StellarKinKit"
  s.description = <<-DESC
                StellarKinKit StellarKinKit StellarKinKit StellarKinKit StellarKinKit
                DESC
  s.author      = { 'Kin Foundation' => 'kin@kik.com' }
  s.source      = { :git => "https://github.com/kinfoundation/StellarKinKit.git", :submodules => true}
  s.source_files = "StellarKinKit/source/*.swift"
  s.ios.deployment_target = "8.0"

  s.subspec 'Sodium' do |sod|
    sod.ios.deployment_target = '8.0'
    sod.ios.vendored_library    = 'swift-sodium/Sodium/libsodium/libsodium-ios.a'
    sod.source_files = 'swift-sodium/Sodium/**/*.{swift,h}'
    sod.private_header_files = 'swift-sodium/Sodium/libsodium/*.h'
    sod.preserve_paths = 'swift-sodium/Sodium/libsodium/module.modulemap'
    sod.pod_target_xcconfig = {
    	'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/swift-sodium/Sodium/libsodium',
    }
    sod.requires_arc = true
  end

  s.subspec 'KeychainSwift' do |chn|
    chn.source_files = "keychain-swift/KeychainSwift/*.swift"
    chn.ios.deployment_target = "8.0"
  end

end
