//
//  DiscuzClient+Teleport.swift
//  Stage1st
//
//  Created by Zheng Li on 5/24/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import Alamofire
import JASON

public let kStage1stDomain = "Stage1stDomain"

//struct DZError: Error {
//    enum Code: Int, _ErrorCodeProtocol {
//        public typealias _ErrorType = DZError
//
//        case loginFailedResponse
//    }
//}

private func generateURLString(_ baseURLString: String, parameters: Parameters) -> String {
    let urlRequest = URLRequest(url: URL(string: baseURLString)!)
    let encodedURLRequest = try? URLEncoding.queryString.encode(urlRequest, with: parameters)
    return encodedURLRequest?.url?.absoluteString ?? "" // FIXME: this should not be nil.
}

// MARK: - Login
public extension DiscuzClient {
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
        let parameters: Parameters = [
            "module": "secure",
            "version": 1,
            "mobile": "no",
            "type": "login"
        ]
        return Alamofire.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseJASON { (response) in
            debugPrint(response.request as Any)
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
    public func logIn(username: String, password: String, secureQuestionNumber: Int, secureQuestionAnswer: String, authMode: AuthMode, completion: @escaping (Result<String?>) -> Void) -> Request {
        var URLParameters: Parameters = [
            "module": "login",
            "version": 1,
            "loginsubmit": "yes",
            "loginfield": "auto",
            "cookietime": 2592000,
            "mobile": "no"
        ]

        if case .secure(let hash, let code) = authMode {
            URLParameters["sechash"] = hash
            URLParameters["seccodeverify"] = code
        }
        let URLString = generateURLString(baseURL + "/api/mobile/", parameters: URLParameters)

        let bodyParameters: Parameters = [
            "username": username,
            "password": password,
            "questionid": secureQuestionNumber,
            "answer": secureQuestionAnswer
        ]

        return Alamofire.request(URLString, method: .post, parameters: bodyParameters).responseJASON { (response) in
            debugPrint(response.request as Any)
            switch response.result {
            case .success(let json):
                if let messageValue = json["Message"]["messageval"].string, messageValue.contains("login_succeed") {
                    completion(.success(json["Message"]["messagestr"].string))
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: json["Message"]["messagestr"].string ?? NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func getSeccodeImage(sechash: String, completion: @escaping (Result<UIImage>) -> Void) -> Request {
        let parameters: Parameters = ["module": "seccode", "version": 1, "mobile": "no", "sechash": sechash]
        return Alamofire.request(baseURL + "/api/mobile/index.php", method: .get, parameters: parameters, encoding: URLEncoding.queryString, headers: nil).responseData { (response) in
            switch response.result {
            case .success(let data):
                if let image = UIImage(data: data) {
                    completion(.success(image))
                } else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("LoginView_Get_Login_Status_Failure_Message", comment: "")])
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func logOut(_ completionHandler: () -> Void = {}) {
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
        completionHandler()
    }

    func isInLogin() -> Bool { // TODO: check cookies rather than a global state.
        if let _ = UserDefaults.standard.object(forKey: "InLoginStateID") as? String {
            return true
        } else {
            return false
        }
    }
}

// MARK: - Profile
public extension DiscuzClient {
    @discardableResult
    public func profile(userID: UInt, completion: @escaping (Result<User>) -> Void) -> Request {
        let parameters: Parameters = [
            "module": "profile",
            "version": 1,
            "uid": userID,
            "mobile": "no"
        ]

        return Alamofire.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseJASON { (response) in
            switch response.result {
            case .success(let json):
                guard let user = User(json: json) else {
                    let error = NSError(domain: kStage1stDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user info."])
                    completion(.failure(error))
                    return
                }
                completion(.success(user))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Report
public extension DiscuzClient {
    @discardableResult
    func report(topicID: String, floorID: String, forumID: String, reason: String, formhash: String, completion: @escaping (Error?) -> Void) -> Request {
        let URLParameters: Parameters = [
            "mod": "report",
            "inajax": 1
        ]

        let URLString = generateURLString(baseURL + "/misc.php", parameters: URLParameters)

        let bodyParameters: Parameters = [
            "report_select": "其他",
            "message": reason,
            "referer": baseURL + "/forum.php?mod=viewthread&tid=\(topicID)",
            "reportsubmit": "true",
            "rtype": "post",
            "rid": floorID,
            "fid": forumID,
            "url": "",
            "inajax": 1,
            "handlekey": "miscreport1",
            "formhash": formhash
        ]

        return Alamofire.request(URLString, method: .post, parameters: bodyParameters).responseString { (response) in
            completion(response.result.error)
        }
    }
}
