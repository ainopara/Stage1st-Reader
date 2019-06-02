//
//  NavigationControllerDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/20.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import UIKit

class NavigationControllerDelegate: NSObject {

    weak var navigationController: UINavigationController?
    lazy var panRecognizer: UIPanGestureRecognizer = { UIPanGestureRecognizer(target: self, action: #selector(pan(_:))) }()

    private var interactionController: UIPercentDrivenInteractiveTransition?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController

        super.init()

        panRecognizer.delegate = self
        navigationController.view.addGestureRecognizer(panRecognizer)
    }
}

// MARK: - Action

extension NavigationControllerDelegate {

    @objc func pan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view else {
            assert(false, "this should never happen!")
            S1LogError("this should never happen!")
            return
        }

        let translation = gestureRecognizer.translation(in: view)

        switch gestureRecognizer.state {
        case .began:
            interactionController = UIPercentDrivenInteractiveTransition()
            navigationController?.popViewController(animated: true)
            S1LogDebug("Begin")
        case .changed:
            let width = view.bounds.width
            let percent = max(translation.x / width, 0.0)
            interactionController?.update(percent)
            S1LogVerbose("Update: \(percent)")
        case .ended:
            let width = view.bounds.width
            let velocityX = gestureRecognizer.velocity(in: view).x

            let triggerThreshold: CGFloat = 60.0
            let triggerVelocityThreshold: CGFloat = 500.0

            let shouldFinish = (translation.x > triggerThreshold && velocityX >= -100.0) || velocityX > triggerVelocityThreshold

            if shouldFinish {
                let timeLeft = (width - min(translation.x, 0.0)) / abs(velocityX)
                interactionController?.completionSpeed = 0.3 / min(timeLeft, 0.3)
                interactionController?.finish()
                S1LogDebug("Finish with speed: \(String(describing: interactionController?.completionSpeed))")
            } else {
                let timeUsed = abs(translation.x / velocityX)
                interactionController?.completionSpeed = 0.3 / min(timeUsed, 0.3)
                interactionController?.cancel()
                S1LogDebug("Cancel with speed: \(String(describing: interactionController?.completionSpeed))")
            }

            interactionController = nil
        case .possible:
            S1LogDebug("Possible")
        case .failed, .cancelled:
            S1LogDebug("\(gestureRecognizer.state.rawValue)")
            interactionController?.cancel()
            interactionController = nil
        @unknown default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension NavigationControllerDelegate: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.panRecognizer {
            if navigationController?.viewControllers.count != 1 {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension NavigationControllerDelegate: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            return S1Animator(direction: .push)
        case .pop:
            return S1Animator(direction: .pop)
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        return self.interactionController
    }

    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        if AppEnvironment.current.settings.forcePortraitForPhone.value && UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }
}
