source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "10.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'AFNetworking'
    pod 'Alamofire'
    pod 'AlamofireImage'

    # Model
    pod 'SwiftyJSON', :git => 'https://github.com/ainopara/SwiftyJSON.git'
    pod 'CodableExtensions'

    # UI
    pod 'ActionSheetPicker-3.0'
    pod 'JTSImageViewController', :git => 'https://github.com/ainopara/JTSImageViewController.git'

    pod 'Masonry'
    pod 'SnapKit'

    pod 'YYKeyboardManager'
    pod 'TextAttributes'
    pod 'HorizontalFloatingHeaderLayout'

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
    pod 'AppCenter'
    pod 'Reachability'
    pod 'Reveal-SDK', :configurations => ['Debug']
#    pod 'FBMemoryProfiler'

    # Others
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'Fuzi', '~> 2.1'
    pod 'GRMustache.swift', :git => 'https://github.com/ainopara/GRMustache.swift.git'
    pod '1PasswordExtension'
    pod 'AcknowList'
    pod 'QuickTableViewController'
    pod 'Files'
    pod 'DeviceKit'
    pod 'CrashlyticsLogger', '~> 0.3.1'
    pod 'Ainoaibo', :path => './Frameworks/Ainoaibo'

    target "Stage1stTests" do
        inherit! :search_paths
        pod 'iOSSnapshotTestCase'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        pods_with_swift4 = [
            'HorizontalFloatingHeaderLayout'
        ]
        if pods_with_swift4.include? target.name then
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '4.0'
            end
        end

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
