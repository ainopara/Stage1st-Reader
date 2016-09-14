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

        if let touches = event.allTouches, let touch = touches.first, let gestureRecognizers = touch.gestureRecognizers {
            for gestureRecognizer in gestureRecognizers {
                if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
                    DDLogVerbose("\(panGestureRecognizer) - \(panGestureRecognizer.minimumNumberOfTouches) - \(panGestureRecognizer.maximumNumberOfTouches)")
                }
            }
        }
    }
}
