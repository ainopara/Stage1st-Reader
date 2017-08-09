//
//  S1NavigationViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 12/2/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

class S1NavigationViewController: UINavigationController {

    var gagat: Gagat.TransitionHandle?
    override func viewDidLoad() {
        super.viewDidLoad()

        interactivePopGestureRecognizer?.isEnabled = false
    }
}

extension NavigationControllerDelegate {
    @objc func setUpGagat() {
        let handle = Gagat.configure(for: MyAppDelegate.window, with: self)
        self.navigationController?.gagat = handle
        self.colorPanRecognizer = handle.panGestureRecognizer
    }
}

extension NavigationControllerDelegate: GagatStyleable {
    public func shouldStartTransition(with direction: TransitionCoordinator.Direction) -> Bool {
        let currentInNightMode = UserDefaults.standard.bool(forKey: Constants.defaults.nightModeKey)
        if currentInNightMode {
            return direction == .up
        } else {
            return direction == .down
        }
    }

    public func toggleActiveStyle() {
        if UserDefaults.standard.bool(forKey: Constants.defaults.nightModeKey) {
            UserDefaults.standard.set(false, forKey: Constants.defaults.nightModeKey)
            ColorManager.shared.switchPalette(.day)
        } else {
            UserDefaults.standard.set(true, forKey: Constants.defaults.nightModeKey)
            ColorManager.shared.switchPalette(.night)
        }
    }
}
