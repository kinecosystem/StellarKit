Pod::Spec.new do |s|
  s.name        = "StellarKit"
  s.version     = "0.4.0"
  s.license     = { :type => "Kin Ecosystem SDK License" }
  s.homepage    = "https://github.com/kinecosystem/StellarKit.git"
  s.summary     = "A framework for communicating with a Stellar Horizon node"
  s.description = <<-DESC
		StellarKit implements a minimum set operations required to implement the KIN crypto-currency on top of Stellar. Contributions to extend the repertoire of available operations will be considered.
                DESC
  s.author      = { 'Kin' => 'info@kin.org' }
  s.source      = { :git => "https://github.com/kinecosystem/StellarKit.git", :tag => s.version, :submodules => true }

  s.dependency 'KinUtil', '0.1.0'
  s.dependency 'StellarErrors', '0.4.0'

  s.ios.deployment_target = "8.0"
  s.swift_version = "5.0"

  s.source_files = 'StellarKit/source/*.swift',
                   'StellarKit/source/types/*.swift',
                   'StellarKit/source/XDRCodable/XDRCodable.swift',
                   'StellarKit/third-party/SHA256.swift'
end
