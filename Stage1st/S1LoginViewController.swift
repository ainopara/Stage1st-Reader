//
//  S1LoginViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

extension S1LoginViewController {
    func tryLogin() {
        guard let username = self.usernameField.text, password = self.passwordField.text where username != "" && password != "" else {
            self.alertMessage("用户名和密码不能为空")
            return
        }
        NSUserDefaults.standardUserDefaults().setObject(username, forKey: "UserIDCached")

        LoginManager.sharedInstance.checkLoginType(noSechashBlock: {
            LoginManager.sharedInstance.login(username, password: password, secureQuestionNumber: 0, secureQuestionAnswer: "", successBlock: { (message) in
                NSUserDefaults.standardUserDefaults().setObject(username, forKey: "InLoginStateID")
                self.updateUI()
                let alertController = UIAlertController(title: NSLocalizedString("SettingView_Login", comment:""), message: message ?? "登录成功", preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: { action in
                    self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                }))
                self.presentViewController(alertController, animated: true, completion: nil)
                }, failureBlock: { (error) in
                    self.alertMessage(error.localizedDescription)
            })
        }, hasSeccodeBlock: { (sechash) in
            self.alertMessage("尚未实现验证码登录功能")
        }, failureBlock: { (error) in
            self.alertMessage(error.localizedDescription)
        })
    }
}

// MARK: Helper
extension S1LoginViewController {
    private func alertMessage(message: String) {
        let alertController = UIAlertController(title: NSLocalizedString("SettingView_Login", comment:""), message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Message_OK", comment:""), style: .Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
}
