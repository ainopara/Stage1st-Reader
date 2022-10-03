source 'https://cdn.cocoapods.org/'
platform :ios, "13.1"
use_frameworks! :linkage => :static

target "Stage1st" do
    # Network
    pod 'Alamofire', '~> 5.0'

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
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'release/3.1.4'

    # XML
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod 'Fuzi', '~> 3.0'
    pod 'Html', '~> 0.3'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'

    pod 'Sentry'

    pod 'OHHTTPStubs/Swift', :configurations => ['Debug']
    pod 'OHHTTPStubs/HTTPMessage', :configurations => ['Debug']
    pod 'SWHttpTrafficRecorder', :configurations => ['Debug']

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
#        pod 'SnapshotTesting', '~> 1.1'
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
            'Fuzi'
        ]
        if pods_with_swift4_2.include? target.name then
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '4.2'
            end
        end

        target.build_configurations.each do |config|
            if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 13.0
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
            end
            config.build_settings["DEVELOPMENT_TEAM"] = "ZXQ9B2EVU5"
        end
    end
end
