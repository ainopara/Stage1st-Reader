//
//  S1UserViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

final class S1UserViewController: UIViewController {
    let user: User

    // MARK: - Life Cycle
    init(user: User) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
