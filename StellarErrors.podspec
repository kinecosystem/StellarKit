Pod::Spec.new do |s|
  s.name        = "StellarErrors"
  s.version     = "0.4.0"
  s.license     = { :type => "Kin Ecosystem SDK License" }
  s.homepage    = "https://github.com/kinecosystem/StellarKit.git"
  s.summary     = "A framework describing the errors that may be raised by StellarKit."
  s.description = <<-DESC
		StellarKit implements a minimum set operations required to implement the KIN crypto-currency on top of Stellar. Contributions to extend the repertoire of available operations will be considered.
                DESC
  s.author      = { 'Kin Foundation' => 'info@kin.org' }
  s.source      = { :git => "https://github.com/kinecosystem/StellarKit.git", :tag => s.version, :submodules => true }

  s.ios.deployment_target = "8.0"
  s.swift_version = "5.0"

  s.source_files          = 'StellarErrors/*.swift'
end
