source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "9.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'AFNetworking'
    pod 'Alamofire'
    pod 'AlamofireImage'

    # Model
    pod 'SwiftyJSON', :git => 'https://github.com/ainopara/SwiftyJSON.git'

    # UI
    pod 'ActionSheetPicker-3.0'
    pod 'JTSImageViewController', :git => 'https://github.com/ainopara/JTSImageViewController.git'

    pod 'Masonry'
    pod 'SnapKit'

    pod 'YYKeyboardManager'
    pod 'TextAttributes'

    # Database
    pod 'FMDB'
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'stage'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    pod 'ReactiveCocoa'
    pod 'ReactiveSwift'

    pod 'Fabric'
    pod 'Crashlytics'
    pod 'Reachability'
    pod 'Reveal-SDK', :configurations => ['Debug']
#    pod 'FBMemoryProfiler'

    # Others
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'GRMustache.swift', :git => 'https://github.com/iina/GRMustache.swift.git'
    pod '1PasswordExtension'
    pod 'AcknowList'
    pod 'QuickTableViewController'
    pod 'Files'
    pod 'DeviceKit'
    pod 'CrashlyticsLogger', :path => '../CrashlyticsLogger'
    pod 'Ainoaibo', :path => '../Ainoaibo'

    target "Stage1stTests" do
        inherit! :search_paths
        pod 'GYHttpMock'
        pod 'FBSnapshotTestCase'
        pod 'KIF', :configurations => ['Debug']
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        pods_with_swift3 = [
            'TextAttributes',
        ]
        if pods_with_swift3.include? target.name then
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.0'
            end
        end
    end
end
