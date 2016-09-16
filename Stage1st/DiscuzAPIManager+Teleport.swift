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

private func generateURLString(_ baseURLString: String, parameters: [String: Any]) -> String {
    let urlRequest = URLRequest(url: URL(string: baseURLString)!)
    let encodedURLRequest = try? URLEncoding.queryString.encode(urlRequest, with: parameters)
    return encodedURLRequest?.url?.absoluteString ?? "" // FIXME: this should not be nil.
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
    @discardableResult
    public func checkLoginType(noSechashBlock: @escaping () -> Void,
                               hasSeccodeBlock: @escaping (_ sechash: String) -> Void,
                               failureBlock: @escaping (_ error: NSError) -> Void) -> Request {
        logOut()
        let parameters: [String: Any] = ["module": "secure", "version": 1, "mobile": "no", "type": "login"]
        return Alamofire.request(baseURL + "/api/mobile/index.php", method: .get, parameters: parameters, encoding: URLEncoding.default, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .success(let json):
                if let sechash = json["Variables"]["sechash"].string {
                    hasSeccodeBlock(sechash)
                } else {
                    noSechashBlock()
                }
            case .failure(let error):
                failureBlock(error as NSError)
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
    @discardableResult
    public func logIn(username: String,
               password: String,
               secureQuestionNumber: Int,
               secureQuestionAnswer: String,
               authMode: AuthMode,
               successBlock: @escaping (_ message: String?) -> Void,
               failureBlock: @escaping (_ error: NSError) -> Void) -> Request {
        // Generate URLString
        var URLParameters: [String: Any] = ["module": "login", "version": 1, "loginsubmit": "yes", "loginfield": "auto", "cookietime": 2592000, "mobile": "no"]
        if case .secure(let hash, let code) = authMode {
            URLParameters["sechash"] = hash
            URLParameters["seccodeverify"] = code
        }
        let URLString = generateURLString(baseURL + "/api/mobile/", parameters: URLParameters)

        let bodyParameters: [String: Any] = ["username": username, "password": password, "questionid": secureQuestionNumber, "answer": secureQuestionAnswer]
        return Alamofire.request(URLString, method: .post, parameters: bodyParameters, encoding: URLEncoding.default, headers: nil).responseJASON { (response) in
            debugPrint(response.request)
            switch response.result {
            case .success(let json):
                if let messageValue = json["Message"]["messageval"].string, (messageValue as NSString).contains("login_succeed") {
                    successBlock(json["Message"]["messagestr"].string)
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: json["Message"]["messagestr"].string ?? NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    failureBlock(error)
                }
            case .failure(let error):
                failureBlock(error as NSError)
            }
        }
    }

    @discardableResult
    func getSeccodeImage(sechash: String,
                         successBlock: @escaping (_ image: UIImage) -> Void,
                         failureBlock: @escaping (_ error: NSError) -> Void) -> Request {
        let parameters: [String: Any] = ["module": "seccode", "version": 1, "mobile": "no", "sechash": sechash]
        return Alamofire.request(baseURL + "/api/mobile/index.php", method: .get, parameters: parameters, encoding: URLEncoding.queryString, headers: nil).responseData { (response) in
            switch response.result {
            case .success(let data):
                if let image = UIImage(data: data) {
                    successBlock(image)
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    failureBlock(error)
                }
            case .failure(let error):
                failureBlock(error as NSError)
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
    @discardableResult
    public func profile(_ userID: Int, responseBlock: @escaping (_ result: Result<User>) -> Void) -> Request {
        let parameters: [String: Any] = ["module": "profile", "version": 1, "uid": userID, "mobile": "no"]
        return Alamofire.request(baseURL + "/api/mobile/index.php", method: .get, parameters: parameters, encoding: URLEncoding.default, headers: nil).responseJASON { (response) in
            switch response.result {
            case .success(let json):
                guard let user = User(json: json) else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user info."])
                    responseBlock(.failure(error))
                    return
                }
                responseBlock(.success(user))
            case .failure(let error):
                responseBlock(.failure(error))
            }
        }
    }
}

// MARK: - Report
public extension DiscuzAPIManager {
    @discardableResult
    func report(_ topicID: String,
                floorID: String,
                forumID: String,
                reason: String,
                formhash: String,
                completion: @escaping (NSError?) -> Void) -> Request {
        let URLParameters: [String: Any] = ["mod": "report", "inajax": 1]
        let URLString = generateURLString(baseURL + "/misc.php", parameters: URLParameters)

        let bodyParameters: [String: Any] = ["report_select": "其他", "message": reason, "referer": baseURL + "/forum.php?mod=viewthread&tid=\(topicID)", "reportsubmit": "true", "rtype": "post", "rid": floorID, "fid": forumID, "url": "", "inajax": 1, "handlekey": "miscreport1", "formhash": formhash]
        return Alamofire.request(URLString, method: .post, parameters: bodyParameters, encoding: URLEncoding.default).responseString { (response) in
            completion(response.result.error as NSError?)
        }
    }
}
