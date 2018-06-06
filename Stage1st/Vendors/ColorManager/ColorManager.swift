//
//  ColorManager.swift
//  Stage1st
//
//  Created by Zheng Li on 11/12/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

@objcMembers
public final class ColorManager: NSObject {
    private var palette = [String: Any]()
    private var colorMap = [String: String]()
    private let fallbackColor = UIColor.black
    private let defaultPaletteURL = Bundle.main.url(forResource: "DarkPalette", withExtension: "plist")

    init(nightMode: Bool) {
        super.init()

        let paletteName = nightMode ? "DarkPalette": "DefaultPalette"

        let palettePath = Bundle.main.path(forResource: paletteName, ofType: "plist")
        if
            let palettePath = palettePath,
            let palette = NSDictionary(contentsOfFile: palettePath) as? [String: Any]
        {
            self.palette = palette
        }

        let colorMapPath = Bundle.main.path(forResource: "ColorMap", ofType: "plist")
        if
            let colorMapPath = colorMapPath,
            let colorMap = NSDictionary(contentsOfFile: colorMapPath) as? [String: String]
        {
            self.colorMap = colorMap
        }
    }

    public func switchPalette(_ type: PaletteType) {
        let paletteName: String = type == .night ? "DarkPalette" : "DefaultPalette"
        let paletteURL = Bundle.main.url(forResource: paletteName, withExtension: "plist")
        loadPaletteByURL(paletteURL, shouldPushNotification: true)
    }

    public func htmlColorStringWithID(_ paletteID: String) -> String {
        return palette[paletteID] as? String ?? "#000000"
    }

    public func isDarkTheme() -> Bool {
        return palette["Dark"] as? Bool ?? false
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
            NSAttributedStringKey.foregroundColor.rawValue: self.colorForKey("appearance.searchbar.text"),
            NSAttributedStringKey.font.rawValue: UIFont.systemFont(ofSize: 14.0)
        ]
        UIScrollView.appearance().indicatorStyle = isDarkTheme() ? .white : .default
        UITextField.appearance().keyboardAppearance = isDarkTheme() ? .dark : .default
        (UIApplication.shared.delegate as! S1AppDelegate).window?.backgroundColor = colorForKey("window.background")
    }

    public func colorForKey(_ key: String) -> UIColor {
        if let paletteID = colorMap[key] {
            return colorInPaletteWithID(paletteID)
        } else {
            S1LogWarn("[Color Manager] can't found color \(key), default color used")
            return colorInPaletteWithID("default")
        }
    }
}

// MARK: - Private

private extension ColorManager {
    func loadPaletteByURL(_ paletteURL: URL?, shouldPushNotification shouldPush: Bool) {
        guard
            let paletteURL = paletteURL,
            let palette = NSDictionary(contentsOf: paletteURL) as? [String: Any]
        else {
            return
        }

        self.palette = palette

        updateGlobalAppearance()
        if shouldPush {
            NotificationCenter.default.post(name: .APPaletteDidChange, object: nil)
        }
    }

    func colorInPaletteWithID(_ paletteID: String) -> UIColor {
        if
            let colorString = palette[paletteID] as? String,
            let color = S1Global.color(fromHexString: colorString)
        {
            return color
        } else {
            return fallbackColor
        }
    }
}

// MARK: - Miscs

public extension UIViewController {
    @objc public func didReceivePaletteChangeNotification(_ notification: Notification?) {
    }
}

public extension Notification.Name {
    public static let APPaletteDidChange = Notification.Name.init(rawValue: "APPaletteDidChangeNotification")
}

@objc public enum PaletteType: NSInteger {
    case day
    case night
}
