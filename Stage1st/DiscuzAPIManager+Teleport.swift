//
//  DiscuzAPIManager+Login.swift
//  Stage1st
//
//  Created by Zheng Li on 5/24/16.
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

// MARK: - Login
extension DiscuzAPIManager {
    /**
     A check request should be sent to a discuz! server to make sure whether a seccode is necessary for login.

     - parameter noSechashBlock:  Executed if seccode is disabled on this server.
     - parameter hasSeccodeBlock: Executed if seccode is enabled on this server.
     - parameter failureBlock:    Executed if this request failed.

     - returns: Request object.
     */
    func checkLoginType(noSechashBlock noSechashBlock: () -> Void,
                                       hasSeccodeBlock: (sechash: String) -> Void,
                                       failureBlock: (error: NSError) -> Void) -> Request {
        logOut()
        let parameters: [String: AnyObject] = ["module": "secure", "version": 1, "mobile": "no", "type": "login"]
        return Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
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

     - returns: Request object.
     */
    func logIn(username: String,
               password: String,
               secureQuestionNumber: Int,
               secureQuestionAnswer: String,
               successBlock: (message: String?) -> Void,
               failureBlock: (error: NSError) -> Void) -> Request {
        let parameters: [String: AnyObject] = ["username": username, "password": password, "questionid": secureQuestionNumber, "answer": secureQuestionAnswer]
        return Alamofire.request(.POST, baseURL + "/api/mobile/?module=login&version=1&loginsubmit=yes&loginfield=auto&cookietime=2592000&mobile=no", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .Success(let json):
                if let messageValue = json["Message"]["messageval"].string where messageValue.containsString("login_succeed") {
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

    func logOut(finishBlock: () -> Void = {}) {
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

// MARK: - Profile
extension DiscuzAPIManager {
    func profile(userID: Int, responseBlock:(result: Result<User, NSError>) -> Void) -> Request {
        let parameters: [String: AnyObject] = ["module": "profile", "version": 1, "uid": userID, "mobile": "no"]
        return Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            switch response.result {
            case .Success(let json):
                guard let user = User(json: json) else {
                    let error = NSError(domain: "Stage1stReaderDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user info."])
                    responseBlock(result: .Failure(error))
                    return
                }
                responseBlock(result: .Success(user))
            case .Failure(let error):
                responseBlock(result: .Failure(error))
            }
        }
    }
}
