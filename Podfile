source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "8.0"
use_frameworks!

target "Stage1st" do
    # Network
    pod 'AFNetworking'
    pod 'Alamofire'
    pod 'Kingfisher'

    # Model
    pod 'JASON'

    # UI
    pod 'ActionSheetPicker-3.0'
    pod 'JTSImageViewController', :git => 'https://github.com/ainopara/JTSImageViewController.git'

    pod 'Masonry'
    pod 'SnapKit'

    pod 'pop'

    # pod 'DTCoreText'

    # Database
    pod 'FMDB'
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'limit-cloudkit-upload'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'Reveal-iOS-SDK', :configurations => ['Debug']
    # pod 'FBMemoryProfiler'

    # Others
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod '1PasswordExtension'
    pod 'Reachability'
    pod 'SwiftWebViewProgress', :git => 'https://github.com/ainopara/SwiftWebViewProgress.git'
    pod 'ReactiveCocoa'
end

target "Stage1stTests" do
    pod 'GYHttpMock'
    pod 'FBSnapshotTestCase', :git => 'https://github.com/facebook/ios-snapshot-test-case.git'
    pod 'KIF', :configurations => ['Debug']
end
