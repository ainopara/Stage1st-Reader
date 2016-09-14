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

let kStage1stDomain = "Stage1stDomain"

enum LoginProgress {
    case notLogin
    case requestingSechash
    case requestingSeccode
    case logging
    case inLogin
}

private func generateURLString(_ baseURLString: String, parameters: [String: AnyObject]) -> String {
    let mutableURLRequest = NSMutableURLRequest(url: URL(string: baseURLString)!)
    let encodedURLRequest = ParameterEncoding.URLEncodedInURL.encode(mutableURLRequest, parameters: parameters).0
    return encodedURLRequest.URLString
}

// MARK: - Login
public extension DiscuzAPIManager {
    /**
     A check request should be sent to a discuz! server to make sure whether a seccode is necessary for login.

     - parameter noSechashBlock:  Executed if seccode is disabled on this server.
     - parameter hasSeccodeBlock: Executed if seccode is enabled on this server.
     - parameter failureBlock:    Executed if this request failed.

     - returns: Request object.
     */
    public func checkLoginType(noSechashBlock: () -> Void,
                               hasSeccodeBlock: (_ sechash: String) -> Void,
                               failureBlock: (_ error: NSError) -> Void) -> Request {
        logOut()
        let parameters: [String: Any] = ["module": "secure", "version": 1, "mobile": "no", "type": "login"]
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

    public enum AuthMode {
        case basic
        case secure(hash: String, code: String)
    }

    /**
     Request to login when seccode is not necessary.

     - parameter username:             Username of account.
     - parameter password:             Password of account.
     - parameter secureQuestionNumber: Secure question number of account. This should be set to 0 if no question is setted.
     - parameter secureQuestionAnswer: Answer of secure question of account.
     - parameter authMode:             Auth mode for log in.
     - parameter successBlock:         Executed if login request finished without network error.
     - parameter failureBlock:         Executed if login request not finished due to network error.

     - returns: Request object.
     */
    public func logIn(username: String,
               password: String,
               secureQuestionNumber: Int,
               secureQuestionAnswer: String,
               authMode: AuthMode,
               successBlock: (_ message: String?) -> Void,
               failureBlock: (_ error: NSError) -> Void) -> Request {
        // Generate URLString
        var URLParameters: [String: Any] = ["module": "login", "version": 1, "loginsubmit": "yes", "loginfield": "auto", "cookietime": 2592000, "mobile": "no"]
        if case .Secure(let hash, let code) = authMode {
            URLParameters["sechash"] = hash
            URLParameters["seccodeverify"] = code
        }
        let URLString = generateURLString(baseURL + "/api/mobile/", parameters: URLParameters)

        let bodyParameters: [String: AnyObject] = ["username": username, "password": password, "questionid": secureQuestionNumber, "answer": secureQuestionAnswer]
        return Alamofire.request(.POST, URLString, parameters: bodyParameters, encoding: .URL, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .Success(let json):
                if let messageValue = json["Message"]["messageval"].string , messageValue.containsString("login_succeed") {
                    successBlock(message: json["Message"]["messagestr"].string)
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: json["Message"]["messagestr"].string ?? NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    failureBlock(error: error)
                }
            case .Failure(let error):
                failureBlock(error: error)
            }
        }
    }

    func getSeccodeImage(sechash: String,
                         successBlock: (_ image: UIImage) -> Void,
                         failureBlock: (_ error: NSError) -> Void) -> Request {
        let parameters: [String: AnyObject] = ["module": "seccode", "version": 1, "mobile": "no", "sechash": sechash]
        return Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URLEncodedInURL, headers: nil).responseData { (response) in
            switch response.result {
            case .Success(let data):
                if let image = UIImage(data: data) {
                    successBlock(image: image)
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    failureBlock(error: error)
                }
            case .Failure(let error):
                failureBlock(error: error)
            }
        }
    }

    func logOut(_ finishBlock: () -> Void = {}) {
        func clearCookies() {
            let cookieStorage = HTTPCookieStorage.shared
            if let cookies = cookieStorage.cookies {
                for cookie in cookies {
                    cookieStorage.deleteCookie(cookie)
                }
            }
        }
        clearCookies() // TODO: only delete cookies about this account.
        UserDefaults.standard.set(nil, forKey: "InLoginStateID") // TODO: move this to finish block.
        finishBlock()
    }

    func isInLogin() -> Bool { // TODO: check cookies rather than a global state.
        let loginID: String? = UserDefaults.standard.object(forKey: "InLoginStateID") as? String
        return loginID == nil
    }
}

// MARK: - Profile
public extension DiscuzAPIManager {
    public func profile(_ userID: Int, responseBlock:(_ result: Result<User, NSError>) -> Void) -> Request {
        let parameters: [String: AnyObject] = ["module": "profile", "version": 1, "uid": userID, "mobile": "no"]
        return Alamofire.request(.GET, baseURL + "/api/mobile/index.php", parameters: parameters, encoding: .URL, headers: nil).responseJASON { (response) in
            switch response.result {
            case .Success(let json):
                guard let user = User(json: json) else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user info."])
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

// MARK: - Report
public extension DiscuzAPIManager {
    func report(_ topicID: String, floorID: String, forumID: String, reason: String, formhash: String, completion: (NSError?) -> Void) -> Request {
        let URLParameters: [String: Any] = ["mod": "report", "inajax": 1]
        let URLString = generateURLString(baseURL + "/misc.php", parameters: URLParameters)

        let bodyParameters: [String: AnyObject] = ["report_select": "其他", "message": reason, "referer": baseURL + "/forum.php?mod=viewthread&tid=\(topicID)", "reportsubmit": "true", "rtype": "post", "rid": floorID, "fid": forumID, "url": "", "inajax": 1, "handlekey": "miscreport1", "formhash": formhash]
        return Alamofire.request(.POST, URLString, parameters: bodyParameters, encoding: .URL).responseString { (response) in
            completion(response.result.error)
        }
    }
}
