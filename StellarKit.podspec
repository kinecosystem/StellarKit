Pod::Spec.new do |s|
  s.name        = "StellarKit"
  s.version     = "0.3.15"
  s.license     = { :type => "MIT" }
  s.homepage    = "https://github.com/kinecosystem/StellarKit.git"
  s.summary     = "A framework for communicating with a Stellar Horizon node"
  s.description = <<-DESC
		StellarKit implements a minimum set operations required to implement the KIN crypto-currency on top of Stellar. Contributions to extend the repertoire of available operations will be considered.
                DESC
  s.author      = { 'Kin' => 'info@kin.org' }
  s.source      = { :git => "https://github.com/kinecosystem/StellarKit.git", :tag => s.version, :submodules => true }

  s.dependency 'KinUtil', '0.0.17'
  s.dependency 'StellarErrors', '0.2.7'

  s.ios.deployment_target = "8.0"
  s.swift_version = "4.2"

  s.source_files = 'StellarKit/source/*.swift',
                   'StellarKit/source/types/*.swift',
                   'StellarKit/source/XDRCodable/XDRCodable.swift',
                   'StellarKit/third-party/SHA256.swift'
end
