//
//  RootNavigationController.swift
//  Stage1st
//
//  Created by Zheng Li on 12/2/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

class RootNavigationController: UINavigationController {

    lazy var gagatTransitionHandle: Gagat.TransitionHandle = {
        Gagat.configure(for: UIApplication.shared.delegate!.window!!, with: self)
    }()
    var colorPanRecognizer: UIPanGestureRecognizer { return gagatTransitionHandle.panGestureRecognizer }

    override func viewDidLoad() {
        super.viewDidLoad()

        colorPanRecognizer.maximumNumberOfTouches = 5
        interactivePopGestureRecognizer?.isEnabled = false
        isNavigationBarHidden = true
    }
}

// MARK: - GagatStyleable

extension RootNavigationController: GagatStyleable {

    public func shouldStartTransition(with direction: TransitionCoordinator.Direction) -> Bool {

        guard AppEnvironment.current.settings.gestureControledNightModeSwitch.value else {
            return false
        }

        guard AppEnvironment.current.settings.manualControlInterfaceStyle.value else {
            return false
        }

        if AppEnvironment.current.settings.nightMode.value == true {
            return direction == .up
        } else {
            return direction == .down
        }
    }

    public func toggleActiveStyle() {
        if AppEnvironment.current.settings.nightMode.value == true {
            AppEnvironment.current.settings.nightMode.value = false
        } else {
            AppEnvironment.current.settings.nightMode.value = true
        }
    }
}
