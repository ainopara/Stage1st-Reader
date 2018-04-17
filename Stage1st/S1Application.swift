//
//  S1Application.swift
//  Stage1st
//
//  Created by Zheng Li on 11/29/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

class S1Application: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        // Debug touch events
        guard event.type == .touches else {
            return
        }

        guard let touches = event.allTouches,
            let touch = touches.first,
            let gestureRecognizers = touch.gestureRecognizers else {
            return
        }

        for gestureRecognizer in gestureRecognizers {
            if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
                S1LogVerbose("\(panGestureRecognizer) - \(panGestureRecognizer.minimumNumberOfTouches) - \(panGestureRecognizer.maximumNumberOfTouches)")
            }
        }
    }
}
