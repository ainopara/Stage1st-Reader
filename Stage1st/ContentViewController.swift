//
//  ContentViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/10/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

// MARK: Style
extension S1ContentViewController {
    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}

extension S1ContentViewController {
    func showUserViewController(userID: NSNumber) {
        let viewModel = S1UserViewModel(user: User(ID: userID.integerValue))
        let userViewController = S1UserViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(userViewController, animated: true)
    }
}
