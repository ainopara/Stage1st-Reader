source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "9.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'AFNetworking'
    pod 'Alamofire'
    pod 'AlamofireImage'

    # Model
    pod 'JASON'

    # UI
    pod 'ActionSheetPicker-3.0'
    pod 'JTSImageViewController', :git => 'https://github.com/ainopara/JTSImageViewController.git'

    pod 'Masonry'
    pod 'SnapKit', :git => 'https://github.com/SnapKit/SnapKit.git', :tag => '3.1.2'

    pod 'YYKeyboardManager'
    pod 'TextAttributes'

    # Database
    pod 'FMDB'
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'limit-cloudkit-upload'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    pod 'ReactiveCocoa', :git => 'https://github.com/ReactiveCocoa/ReactiveCocoa.git', :tag => '5.0.0-rc.1'
    pod 'ReactiveSwift'

    pod 'Fabric'
    pod 'Crashlytics'
    pod 'Reachability'
    pod 'Reveal-SDK', :configurations => ['Debug']
    # pod 'FBMemoryProfiler'

    # Others
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'GRMustache.swift'
    pod '1PasswordExtension'

    target "Stage1stTests" do
        inherit! :search_paths
        pod 'GYHttpMock'
        pod 'FBSnapshotTestCase'
        pod 'KIF', :configurations => ['Debug']
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0.1'
        end
    end
end
