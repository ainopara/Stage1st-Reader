//
//  DiscuzClient+Login.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/1.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Alamofire

public extension DiscuzClient {
    /**
     A check request should be sent to a discuz! server to make sure whether a seccode is necessary for login.

     - parameter noSechashBlock:  Executed if seccode is disabled on this server.
     - parameter hasSeccodeBlock: Executed if seccode is enabled on this server.
     - parameter failureBlock:    Executed if this request failed.

     - returns: Request object.
     */
    @discardableResult
    func checkLoginType(
        noSechashBlock: @escaping () -> Void,
        hasSeccodeBlock: @escaping (_ sechash: String) -> Void,
        failureBlock: @escaping (_ error: Error) -> Void
    ) -> Request {

        logOut()
        let parameters: Parameters = [
            "module": "secure",
            "version": 1,
            "mobile": "no",
            "type": "login",
            ]

        struct CheckLoginTypeResult: Decodable {
            let variables: Variables

            private enum  CodingKeys: String, CodingKey {
                case variables = "Variables"
            }

            struct Variables: Decodable {
                let sechash: String
            }
        }

        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseDecodable { (response: DataResponse<CheckLoginTypeResult>) in
            switch response.result {
            case let .success(result):
                hasSeccodeBlock(result.variables.sechash)
            case let .failure(error):
                if let afError = error as? AFError, case AFError.responseSerializationFailed = afError {
                    noSechashBlock()
                } else {
                    failureBlock(error)
                }
            }
        }
    }

    enum AuthMode {
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
    func logIn(
        username: String,
        password: String,
        secureQuestionNumber: Int,
        secureQuestionAnswer: String,
        authMode: AuthMode,
        completion: @escaping (Result<String?, Error>) -> Void
        ) -> Request {
        var URLParameters: Parameters = [
            "module": "login",
            "version": 1,
            "loginsubmit": "yes",
            "loginfield": "auto",
            "cookietime": 2_592_000,
            "mobile": "no",
            ]

        if case let .secure(hash, code) = authMode {
            URLParameters["sechash"] = hash
            URLParameters["seccodeverify"] = code
        }
        let URLString = generateURLString(baseURL + "/api/mobile/", parameters: URLParameters)

        let bodyParameters: Parameters = [
            "username": username,
            "password": password,
            "questionid": secureQuestionNumber,
            "answer": secureQuestionAnswer,
            ]

        struct LoginOperationResult: Decodable {
            let message: RawMessage
            private enum CodingKeys: String, CodingKey {
                case message = "Message"
            }
        }

        return session.request(URLString, method: .post, parameters: bodyParameters, encoding: MultipartFormEncoding.default)
            .responseDecodable { (response: DataResponse<LoginOperationResult>) in
                switch response.result {
                case .success(let operationResult):
                    guard operationResult.message.key.contains("login_succeed") else {
                        completion(.failure(DiscuzError.loginFailed(message: operationResult.message)))
                        return
                    }

                    AppEnvironment.current.settings.currentUsername.value = username
                    NotificationCenter.default.post(name: DiscuzClient.loginStatusDidChangeNotification, object: nil)
                    completion(.success(operationResult.message.description))

                case let .failure(error):
                    if case AFError.responseSerializationFailed = error {
                        let code = response.response?.statusCode ?? 0
                        let mime = response.response?.mimeType ?? ""
                        let body = response.data.map { String(data: $0, encoding: .utf8) ?? "" } ?? ""
                        let recoredError = DiscuzError.loginSerializationFailed(code: code, mime: mime, body: body)
                        AppEnvironment.current.eventTracker.recordError(recoredError)
                    }
                    completion(.failure(error))
                }
        }
    }

    @discardableResult
    func getSeccodeImage(sechash: String, completion: @escaping (Result<UIImage, Error>) -> Void) -> Request {
        let parameters: Parameters = [
            "module": "seccode",
            "version": 1,
            "mobile": "no",
            "sechash": sechash
        ]
        return session.request(baseURL + "/api/mobile/index.php", parameters: parameters).responseData { response in
            switch response.result {
            case let .success(imageData):
                guard let image = UIImage(data: imageData) else {
                    completion(.failure(DiscuzError.loginFetchSeccodeImageFailed))
                    return
                }
                completion(.success(image))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func logOut(_ completionHandler: () -> Void = {}) {
        let cookieStorage = AppEnvironment.current.cookieStorage
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }

        AppEnvironment.current.settings.removeValue(for: .currentUsername) // TODO: move this to finish block.
        NotificationCenter.default.post(name: DiscuzClient.loginStatusDidChangeNotification, object: nil)
        completionHandler()
    }

    func isInLogin() -> Bool { // TODO: check cookies rather than a global state.
        return AppEnvironment.current.settings.currentUsername.value != nil
    }
}
