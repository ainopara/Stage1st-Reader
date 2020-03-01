//
//  PanNavigationController.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/2.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

final class PanNavigationController: UINavigationController {

    //swiftlint:disable weak_delegate
    lazy var panNavigationDelegate = { NavigationControllerDelegate(navigationController: self) }()
    //swiftlint:enable weak_delegate

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = panNavigationDelegate
    }
}
