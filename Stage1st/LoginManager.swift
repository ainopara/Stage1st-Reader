//
//  LoginManager.swift
//  Stage1st
//
//  Created by Zheng Li on 5/8/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import JASON

enum LoginProgress {
    case NotLogin
    case RequestingSechash
    case RequestingSeccode
    case Logging
    case InLogin
}

final class LoginManager: NSObject {
    static let sharedInstance = {
        return LoginManager()
    }()

    let baseURL = "http://bbs.saraba1st.com/2b"

    func checkLoginType(noSechashBlock noSechashBlock: () -> Void, hasSeccodeBlock: (sechash: String) -> Void, failureBlock: (error: NSError) -> Void) {
        clearCookies()
        let parameters: [String: AnyObject] = ["module": "secure", "version": 1, "mobile": "no", "type": "login"]
        Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .Success(let json):
                if let sechash = json["Variables"]["sechash"].string {
                    hasSeccodeBlock(sechash: sechash)
                } else {
                    noSechashBlock()
                }
            case .Failure(let error):
                failureBlock(error: error)
            }
        }
    }

    func login(username: String, password: String, secureQuestionNumber: Int, secureQuestionAnswer: String, successBlock: (message: String?) -> Void, failureBlock: (error: NSError) -> Void) {
        let parameters: [String: AnyObject] = ["username": username, "password": password, "questionid": secureQuestionNumber, "answer": secureQuestionAnswer]
        Alamofire.request(.POST, baseURL + "/api/mobile/?module=login&version=1&loginsubmit=yes&loginfield=auto&mobile=no", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .Success(let json):
                if let messageValue = json["Message"]["messageval"].string where messageValue == "login_succeed" {
                    successBlock(message: json["Message"]["messagestr"].string)
                } else {
                    let error = NSError(domain: "Stage1stReaderDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: json["Message"]["messagestr"].string ?? NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    failureBlock(error: error)
                }
            case .Failure(let error):
                failureBlock(error: error)
            }
        }
    }

    func logout() {
        clearCookies()
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: "InLoginStateID")
    }

    func isInLogin() -> Bool {
        let loginID: String? = NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
        return loginID == nil
    }
}

extension LoginManager {
    private func clearCookies() {
        let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }
}
