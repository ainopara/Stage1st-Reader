source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "10.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'Alamofire', '5.0.0.beta.3'
    pod 'Kingfisher'

    # Model
    pod 'CodableExtensions'

    # UI
    pod 'ActionSheetPicker-3.0'
    pod 'JTSImageViewController', :git => 'https://github.com/ainopara/JTSImageViewController.git'

    pod 'Masonry'
    pod 'SnapKit'

    pod 'YYKeyboardManager'
    pod 'HorizontalFloatingHeaderLayout'

    # Database
    pod 'FMDB'
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'stage'

    # XML
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'Fuzi', '~> 2.1'
    pod 'GRMustache.swift', :git => 'https://github.com/ainopara/GRMustache.swift.git'

    # Debug
    pod 'CocoaLumberjack', '< 3.5.0'
    pod 'CocoaLumberjack/Swift', '< 3.5.0'
    pod 'CrashlyticsLogger', '~> 0.3.1'

    pod 'Fabric'
    pod 'Crashlytics'
    pod 'AppCenter'
#    pod 'Reveal-SDK', :configurations => ['Debug']

    # RAC
    pod 'ReactiveSwift'
    pod 'ReactiveCocoa'

    # Others
    pod 'Reachability'
    pod '1PasswordExtension'
    pod 'AcknowList'
    pod 'QuickTableViewController'
    pod 'Files'
    pod 'DeviceKit'

    # Aibo
    pod 'Ainoaibo/OSLogger', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/InMemoryLogger', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/InMemoryLogViewer', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/LogFormatters', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/SwiftExtension', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/DefaultsBasedSettings', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/StateTransition', :path => './Frameworks/Ainoaibo'
    pod 'Ainoaibo/Stash', :path => './Frameworks/Ainoaibo'

    target "Stage1stTests" do
        inherit! :search_paths
        pod 'iOSSnapshotTestCase'
        pod 'SnapshotTesting', '~> 1.1'
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
    end
end
