#
# Be sure to run `pod lib lint RxNetworkService.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name = 'RxNetworkService'
  s.version = '1.3.2'
  s.swift_version = '5.0'
  s.summary = 'A short description of RxNetworkService.'
  s.requires_arc = true
  s.homepage = 'https://github.com/AdlibBeats/RxNetworkService'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'AdlibBeats' => 'adlibbeats@icloud.com' }
  s.source = { :git => 'https://github.com/AdlibBeats/RxNetworkService.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '13.0'
  s.source_files = 'RxNetworkService/Classes/**/*.{swift}'
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'SWXMLHash', '6.0.0'
end
