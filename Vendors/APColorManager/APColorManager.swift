//
//  APColorManager.swift
//  Stage1st
//
//  Created by Zheng Li on 11/12/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import Foundation
import UIKit

class APColorManager : NSObject {
    var palette: NSDictionary = NSDictionary()
    var colorMap: NSDictionary = NSDictionary()
    let fallbackColor = UIColor.blackColor()
    
    static let sharedInstance = {
        return APColorManager()
    }()
    
    override init () {
        let paletteName = NSUserDefaults.standardUserDefaults().boolForKey("NightMode") == true ? "DarkPalette": "DefaultPalette"
        let palettePath = NSBundle.mainBundle().pathForResource(paletteName, ofType: "plist")
        let colorMapPath = NSBundle.mainBundle().pathForResource("ColorMap", ofType: "plist")
        if let palettePath = palettePath,
        let palette = NSDictionary(contentsOfFile: palettePath) {
            self.palette = palette
        }
        if let colorMapPath = colorMapPath,
        let colorMap = NSDictionary(contentsOfFile: colorMapPath) {
            self.colorMap = colorMap
        }
        super.init()
    }
    
    func setPaletteForNightMode(nightMode: Bool) {
        let paletteName: String = nightMode == true ? "DarkPalette" : "DefaultPalette"
        self.loadPaletteByName(paletteName, shouldPushNotification: true)
    }
    
    func loadPaletteByName(paletteName: String, shouldPushNotification shouldPush: Bool) {
        self.updateGlobalAppearance()
        if (shouldPush) {
            NSNotificationCenter.defaultCenter().postNotificationName("S1PaletteDidChangeNotification", object: nil)
        }
    }
    func htmlColorStringWithID(paletteID: String) -> String {
        return (self.palette.valueForKey(paletteID) as? String) ?? ""
    }
    
    func isDarkTheme() -> Bool {
        return self.palette.valueForKey("Dark")?.boolValue ?? false
    }
    
    func updateGlobalAppearance() {
        UIToolbar.appearance().barTintColor = self.colorForKey("appearance.toolbar.bartint")
        UIToolbar.appearance().tintColor = self.colorForKey("appearance.toolbar.tint")
        UINavigationBar.appearance().barTintColor = self.colorForKey("appearance.navigationbar.bartint")
        UINavigationBar.appearance().tintColor = self.colorForKey("appearance.navigationbar.tint")
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: self.colorForKey("appearance.navigationbar.title"), NSFontAttributeName: UIFont.boldSystemFontOfSize(17.0)]
        UISwitch.appearance().onTintColor = self.colorForKey("appearance.switch.tint")
        if #available(iOS 9.0, *) {
            UITextField.appearanceWhenContainedInInstancesOfClasses([UISearchBar.self]).defaultTextAttributes = [NSForegroundColorAttributeName: self.colorForKey("appearance.searchbar.text"), NSFontAttributeName: UIFont.systemFontOfSize(14.0)]
        } else {
            // Fallback on earlier versions
            S1ColorManager.sharedInstance().updataSearchBarAppearanceWithColor(self.colorForKey("appearance.searchbar.text"))
        }
        UIScrollView.appearance().indicatorStyle = self.isDarkTheme() ? .White : .Default
        UITextField.appearance().keyboardAppearance = self.isDarkTheme() ? .Dark : .Default
        UIApplication.sharedApplication().statusBarStyle = self.isDarkTheme() ? .LightContent : .Default
    }
    
    func colorInPaletteWithID(paletteID : String) -> UIColor {
        let colorString = self.palette.valueForKey(paletteID) as? String
        if let colorString = colorString,
        let color = S1Global.colorFromHexString(colorString) {
            return color
        } else {
            return self.fallbackColor
        }
        
    }
    
    func colorForKey(key: String) -> UIColor {
        let paletteID : String = (self.colorMap.valueForKey(key) as? String) ?? "default"
        return self.colorInPaletteWithID(paletteID)
    }
}
