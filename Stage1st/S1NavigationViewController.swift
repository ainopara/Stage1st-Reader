//
//  S1NavigationViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 12/2/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

class S1NavigationViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        interactivePopGestureRecognizer?.isEnabled = false
    }
}
