source 'https://github.com/CocoaPods/Specs.git'
platform :ios, "9.0"
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

    pod 'DTCoreText'
    pod 'YYKeyboardManager'
    pod 'TextAttributes'

    # Database
    pod 'FMDB'
    pod 'YapDatabase', :git => 'https://github.com/ainopara/YapDatabase.git', :branch => 'limit-cloudkit-upload'

    # Debug
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'Reachability'
    pod 'Reveal-SDK', :configurations => ['Debug']
    # pod 'FBMemoryProfiler'

    # Others
    pod 'KissXML', :git => 'https://github.com/ainopara/KissXML.git'
    pod '1PasswordExtension'
end

target "Stage1stTests" do
    pod 'GYHttpMock'
    pod 'FBSnapshotTestCase'
    pod 'KIF', :configurations => ['Debug']
end
