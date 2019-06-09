source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "10.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'Alamofire', '5.0.0.beta.6'
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
    pod 'GRDB.swift', '~> 3.7'

    # XML
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'Fuzi', '~> 3.0'
    pod 'GRMustache.swift', :git => 'https://github.com/ainopara/GRMustache.swift.git'
    pod 'Html', '~> 0.3'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    pod 'CrashlyticsLogger', '~> 0.4.0'

    pod 'Fabric'
    pod 'Crashlytics'
#    pod 'Reveal-SDK', :configurations => ['Debug']

    # RAC
    pod 'ReactiveSwift', '~> 6.0'
    pod 'ReactiveCocoa', '~> 10.0'

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

        pods_with_swift4_2 = [
            'Fuzi',
            'GRDB.swift'
        ]
        if pods_with_swift4_2.include? target.name then
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '4.2'
            end
        end
    end
end
