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
    static let sharedInstance = { // TODO: LoginManager should not be a singleton, it should be a property of current context
        return LoginManager()
    }()

    let baseURL = "http://bbs.saraba1st.com/2b" // TODO: Replace to configured by a singleton

    /**
     A check request should be sent to a discuz! server to make sure whether a seccode is necessary for login.

     - parameter noSechashBlock:  Executed if seccode is disabled on this server.
     - parameter hasSeccodeBlock: Executed if seccode is enabled on this server.
     - parameter failureBlock:    Executed if this request failed.
     */
    func checkLoginType(noSechashBlock noSechashBlock: () -> Void,
                                       hasSeccodeBlock: (sechash: String) -> Void,
                                       failureBlock: (error: NSError) -> Void) {
        logout()
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

    /**
     Request to login when seccode is not necessary.

     - parameter username:             Username of account.
     - parameter password:             Password of account.
     - parameter secureQuestionNumber: Secure question number of account. This should be set to 0 if no question is setted.
     - parameter secureQuestionAnswer: Answer of secure question of account.
     - parameter successBlock:         Executed if login request finished without network error.
     - parameter failureBlock:         Executed if login request not finished due to network error.
     */
    func login(username: String,
               password: String,
               secureQuestionNumber: Int,
               secureQuestionAnswer: String,
               successBlock: (message: String?) -> Void,
               failureBlock: (error: NSError) -> Void) {
        let parameters: [String: AnyObject] = ["username": username, "password": password, "questionid": secureQuestionNumber, "answer": secureQuestionAnswer]
        Alamofire.request(.POST, baseURL + "/api/mobile/?module=login&version=1&loginsubmit=yes&loginfield=auto&mobile=no", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .Success(let json):
                if let messageValue = json["Message"]["messageval"].string where messageValue.containsString("ogin_succeed") {
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

    func logout(finishBlock: () -> Void = {}) {
        func clearCookies() {
            let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
            if let cookies = cookieStorage.cookies {
                for cookie in cookies {
                    cookieStorage.deleteCookie(cookie)
                }
            }
        }
        clearCookies() // TODO: only delete cookies about this account.
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: "InLoginStateID") // TODO: move this to finish block.
        finishBlock()
    }

    func isInLogin() -> Bool { // TODO: check cookies rather than a global state.
        let loginID: String? = NSUserDefaults.standardUserDefaults().objectForKey("InLoginStateID") as? String
        return loginID == nil
    }
}
