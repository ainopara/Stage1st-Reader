//
//  ColorManager.swift
//  Stage1st
//
//  Created by Zheng Li on 11/12/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit
import Combine

@objcMembers
public final class ColorManager: NSObject {

    private var palette = [String: Any]()
    private var darkPalette = [String: Any]()
    private var colorMap = [String: String]()
    private let fallbackColor = UIColor.black

    weak var window: UIWindow? { didSet { bindTraitCollection() } }
    private let overrideNightMode: CurrentValueSubject<Bool?, Never>
    let resolvedUserInterfaceStyle: CurrentValueSubject<UIUserInterfaceStyle, Never>
    private let traitCollection: CurrentValueSubject<UITraitCollection, Never> = CurrentValueSubject(UITraitCollection.current)

    private var bag = Set<AnyCancellable>()
    private var windowBag = Set<AnyCancellable>()

    init(overrideNightMode: CurrentValueSubject<Bool?, Never>) {
        self.overrideNightMode = overrideNightMode
        self.resolvedUserInterfaceStyle = CurrentValueSubject(.unspecified)

        super.init()

        setupPalette()

        traitCollection
            .map(\.userInterfaceStyle)
            .removeDuplicates()
            .sink { (style) in
                NotificationCenter.default.post(name: .APPaletteDidChange, object: nil, userInfo: nil)
            }
            .store(in: &bag)

        overrideNightMode
            .map { (isNightMode) -> UIUserInterfaceStyle in
                switch isNightMode {
                case .none:
                    return .unspecified
                case .some(true):
                    return .dark
                case .some(false):
                    return .light
                }
            }
            .subscribe(resolvedUserInterfaceStyle)
            .store(in: &bag)

        resolvedUserInterfaceStyle
            .dropFirst(1)
            .sink { [weak self] (style) in
                guard let strongSelf = self else { return }
                strongSelf.window?.overrideUserInterfaceStyle = style
            }
            .store(in: &bag)
    }

    func bindTraitCollection() {
        windowBag = Set<AnyCancellable>()

        guard let window = self.window as? DarkModeDetectWindow else { return }

        window.overrideUserInterfaceStyle = resolvedUserInterfaceStyle.value

        window.traitCollectionSubject
            .subscribe(traitCollection)
            .store(in: &windowBag)
    }

    func setupPalette() {
        if
            let palettePath = Bundle.main.path(forResource: "DefaultPalette", ofType: "plist"),
            let palette = NSDictionary(contentsOfFile: palettePath) as? [String: Any]
        {
            self.palette = palette
        }

        if
            let darkPalettePath = Bundle.main.path(forResource: "DarkPalette", ofType: "plist"),
            let darkPalette = NSDictionary(contentsOfFile: darkPalettePath) as? [String: Any]
        {
            self.darkPalette = darkPalette
        }

        if
            let colorMapPath = Bundle.main.path(forResource: "ColorMap", ofType: "plist"),
            let colorMap = NSDictionary(contentsOfFile: colorMapPath) as? [String: String]
        {
            self.colorMap = colorMap
        }
    }

    @objc(PaletteType)
    public enum PaletteType: Int {
        case day
        case night
    }

    public func isDarkTheme() -> Bool {
        switch self.traitCollection.value.userInterfaceStyle {
        case .dark:
            return true
        case .light, .unspecified:
            fallthrough
        @unknown default:
            return false
        }
    }

    public func updateGlobalAppearance() {
        UIToolbar.appearance().barTintColor = colorForKey("appearance.toolbar.bartint")
        UIToolbar.appearance().tintColor = colorForKey("appearance.toolbar.tint")
        UINavigationBar.appearance().barTintColor = colorForKey("appearance.navigationbar.bartint")
        UINavigationBar.appearance().tintColor = colorForKey("appearance.navigationbar.tint")
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: colorForKey("appearance.navigationbar.title"),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ]
        UISwitch.appearance().onTintColor = colorForKey("appearance.switch.tint")
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
            .foregroundColor: self.colorForKey("appearance.searchbar.text"),
            .font: UIFont.systemFont(ofSize: 14.0)
        ]
        UIScrollView.appearance().indicatorStyle = isDarkTheme() ? .white : .default
        UITextField.appearance().keyboardAppearance = isDarkTheme() ? .dark : .default
    }

    public func colorForKey(_ key: String) -> UIColor {
        if let paletteID = colorMap[key] {
            return colorInPaletteWithID(paletteID)
        } else {
            assertionFailure("[Color Manager] can't found color \(key), default color used")
            return colorInPaletteWithID("default")
        }
    }

    public func htmlColorStringWithID(_ paletteID: String) -> String {
        if isDarkTheme() {
            return darkPalette[paletteID] as? String ?? "#FFFFFF"
        } else {
            return palette[paletteID] as? String ?? "#000000"
        }
    }
}

// MARK: - Private

private extension ColorManager {
    func colorInPaletteWithID(_ paletteID: String) -> UIColor {
        if
            let colorString = palette[paletteID] as? String,
            let color = S1Global.color(fromHexString: colorString),
            let darkColorString = darkPalette[paletteID] as? String,
            let darkColor = S1Global.color(fromHexString: darkColorString)
        {
            return UIColor { (traitCollection) -> UIColor in
                switch traitCollection.userInterfaceStyle {
                case .light, .unspecified:
                    return color
                case .dark:
                    return darkColor
                @unknown default:
                    return color
                }
            }
        } else {
            return fallbackColor
        }
    }
}

// MARK: - Miscs

public extension UIViewController {
    @objc func didReceivePaletteChangeNotification(_ notification: Notification?) {
    }
}

public extension Notification.Name {
    static let APPaletteDidChange = Notification.Name.init(rawValue: "APPaletteDidChangeNotification")
}
