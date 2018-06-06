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
        let handle = Gagat.configure(for: (UIApplication.shared.delegate as! S1AppDelegate).window!, with: self)
        self.navigationController?.gagat = handle
        self.colorPanRecognizer = handle.panGestureRecognizer
    }
}

extension NavigationControllerDelegate: GagatStyleable {
    public func shouldStartTransition(with direction: TransitionCoordinator.Direction) -> Bool {
        if AppEnvironment.current.settings.nightMode.value == true {
            return direction == .up
        } else {
            return direction == .down
        }
    }

    public func toggleActiveStyle() {
        if AppEnvironment.current.settings.nightMode.value == true {
            AppEnvironment.current.settings.nightMode.value = false
            AppEnvironment.current.colorManager.switchPalette(.day)
        } else {
            AppEnvironment.current.settings.nightMode.value = true
            AppEnvironment.current.colorManager.switchPalette(.night)
        }
    }
}
