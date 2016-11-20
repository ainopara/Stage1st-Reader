//
//  APColorManager.swift
//  Stage1st
//
//  Created by Zheng Li on 11/12/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

@objc public enum PaletteType: NSInteger {
    case day
    case night
}

open class APColorManager: NSObject {
    var palette: NSDictionary = NSDictionary()
    var colorMap: NSDictionary = NSDictionary()
    let fallbackColor = UIColor.black
    let defaultPaletteURL = Bundle.main.url(forResource: "DarkPalette", withExtension: "plist")

    open static let shared = {
        return APColorManager()
    }()

    override init () {
        let paletteName = UserDefaults.standard.bool(forKey: "NightMode") == true ? "DarkPalette": "DefaultPalette"

        let palettePath = Bundle.main.path(forResource: paletteName, ofType: "plist")
        if let palettePath = palettePath, let palette = NSDictionary(contentsOfFile: palettePath) {
            self.palette = palette
        }
        let colorMapPath = Bundle.main.path(forResource: "ColorMap", ofType: "plist")
        if let colorMapPath = colorMapPath, let colorMap = NSDictionary(contentsOfFile: colorMapPath) {
            self.colorMap = colorMap
        }
        super.init()
    }

    func switchPalette(_ type: PaletteType) {
        let paletteName: String = type == .night ? "DarkPalette" : "DefaultPalette"
        let paletteURL = Bundle.main.url(forResource: paletteName, withExtension: "plist")
        self.loadPaletteByURL(paletteURL, shouldPushNotification: true)
    }

    func htmlColorStringWithID(_ paletteID: String) -> String {
        return (self.palette.value(forKey: paletteID) as? String) ?? "#000000"
    }

    func isDarkTheme() -> Bool {
        return self.palette.value(forKey: "Dark") as? Bool ?? false
    }

    func updateGlobalAppearance() {
        UIToolbar.appearance().barTintColor = self.colorForKey("appearance.toolbar.bartint")
        UIToolbar.appearance().tintColor = self.colorForKey("appearance.toolbar.tint")
        UINavigationBar.appearance().barTintColor = self.colorForKey("appearance.navigationbar.bartint")
        UINavigationBar.appearance().tintColor = self.colorForKey("appearance.navigationbar.tint")
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: self.colorForKey("appearance.navigationbar.title"), NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17.0)]
        UISwitch.appearance().onTintColor = self.colorForKey("appearance.switch.tint")
        if #available(iOS 9.0, *) {
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSForegroundColorAttributeName: self.colorForKey("appearance.searchbar.text"), NSFontAttributeName: UIFont.systemFont(ofSize: 14.0)]
        } else {
            // Fallback on earlier versions
            S1ColorManager.updataSearchBarAppearance(with: self.colorForKey("appearance.searchbar.text"))
        }
        UIScrollView.appearance().indicatorStyle = self.isDarkTheme() ? .white : .default
        UITextField.appearance().keyboardAppearance = self.isDarkTheme() ? .dark : .default
        UIApplication.shared.statusBarStyle = self.isDarkTheme() ? .lightContent : .default
    }

    func colorForKey(_ key: String) -> UIColor {
        if let paletteID = (self.colorMap.value(forKey: key) as? String) {
            return self.colorInPaletteWithID(paletteID)
        } else {
            DDLogWarn("[Color Manager] can't found color \(key), default color used")
            return self.colorInPaletteWithID("default")
        }
    }
}

// MARK: Private
private extension APColorManager {
    func loadPaletteByURL(_ paletteURL: URL?, shouldPushNotification shouldPush: Bool) {
        guard let paletteURL = paletteURL, let palette = NSDictionary(contentsOf: paletteURL) else {
            return
        }
        self.palette = palette
        self.updateGlobalAppearance()
        if shouldPush {
            NotificationCenter.default.post(name: .APPaletteDidChangeNotification, object: nil)
        }
    }

    func colorInPaletteWithID(_ paletteID: String) -> UIColor {
        let colorString = self.palette.value(forKey: paletteID) as? String
        if let colorString = colorString, let color = S1Global.color(fromHexString: colorString) {
            return color
        } else {
            return self.fallbackColor
        }
    }
}

public extension UIViewController {
    func didReceivePaletteChangeNotification(_ notification: Notification?) {
    }
}

public extension Notification.Name {
    public static let APPaletteDidChangeNotification = Notification.Name.init(rawValue: "APPaletteDidChangeNotification")
}
