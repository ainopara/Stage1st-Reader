plugin 'cocoapods-amimono'
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
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'limit-cloudkit-upload'

    # Debug
    pod 'CocoaLumberjack', :git => 'https://github.com/CocoaLumberjack/CocoaLumberjack.git'
    pod 'CocoaLumberjack/Swift', :git => 'https://github.com/CocoaLumberjack/CocoaLumberjack.git'
    pod 'ReactiveCocoa'
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
    pod 'AcknowList'
    pod 'QuickTableViewController', '~> 0.5.0'
    pod 'SwiftFormat/CLI'

    target "Stage1stTests" do
        inherit! :search_paths
        pod 'GYHttpMock'
        pod 'FBSnapshotTestCase'
        pod 'KIF', :configurations => ['Debug']
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        require 'cocoapods-amimono/patcher'
        Amimono::Patcher.patch!(installer)
    end
end
