//
//  S1Application.swift
//  Stage1st
//
//  Created by Zheng Li on 11/29/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit

class S1Application: UIApplication {
    override func sendEvent(event: UIEvent) {
        super.sendEvent(event)
        // For debug touch events
        /*
        if event.type == .Touches {
            if let touches = event.allTouches(),
                let touch = touches.first,
                let grs = touch.gestureRecognizers {
                    for gr in grs {
                        if let panGr = gr as? UIPanGestureRecognizer {
                            print("\(panGr) - \(panGr.minimumNumberOfTouches) - \(panGr.maximumNumberOfTouches)")
                        }
                    }
            }
        }
        */
        //print("Event sent:\(event)")
    }
}
