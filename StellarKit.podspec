Pod::Spec.new do |s|
  s.name        = "StellarKit"
  s.version     = "0.2.3"
  s.license     = { :type => "MIT" }
  s.homepage    = "https://github.com/kinfoundation/StellarKit.git"
  s.summary     = "A framework for communicating with a Stellar Horizon node"
  s.description = <<-DESC
		StellarKit implements a minimum set operations required to implement the KIN crypto-currency on top of Stellar.  Contributions to extend the repertoire of available operations will be considered.
                DESC
  s.author      = { 'Kin Foundation' => 'kin@kik.com' }
  s.source      = { :git => "https://github.com/kinfoundation/StellarKit.git", :tag => s.version, :submodules => true }

  s.dependency 'KinUtil', '0.0.2'

  s.ios.deployment_target = "8.0"
  s.swift_version = "3.2"

  s.preserve_paths        = 'StellarKit/source/CommonCrypto/*'
  s.source_files          = 'StellarKit/source/**/*.swift'

  s.pod_target_xcconfig   = {
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/StellarKit/source/CommonCrypto'
  }

end
