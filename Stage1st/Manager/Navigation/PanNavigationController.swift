//
//  PanNavigationController.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/2.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

final class PanNavigationController: UINavigationController {

    lazy var panNavigationDelegate = { NavigationControllerDelegate(navigationController: self) }()

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = panNavigationDelegate
    }
}
