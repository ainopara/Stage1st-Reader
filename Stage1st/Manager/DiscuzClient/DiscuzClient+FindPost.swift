//
//  DiscuzClient+FindPost.swift
//  Stage1st
//
//  Created by Zheng Li on 2022/10/5.
//  Copyright © 2022 Renaissance. All rights reserved.
//

import Alamofire

public extension DiscuzClient {

    @discardableResult
    func findPost(
        with referenceURLString: String,
        completion: @escaping (Result<S1Topic, Error>) -> Void
    ) -> Alamofire.Request {

        guard let url = URL(string: referenceURLString) else {
            defer { completion(.failure("Failed to generate url with urlString: \(referenceURLString)")) }
            return session.request(FailureURL("Failed to generate url with baseURL: \(baseURL) path: \(referenceURLString)"))
                .response(completionHandler: { (response) in })
        }

        return session
            .request(url, method: .get)
            .redirect(using: .doNotFollow)
            .response(completionHandler: { (response) in
                guard let response = response.response else {
                    completion(.failure("Failed to get response from requesting URL: \(url) Error: \(String(describing: response.error))"))
                    return
                }
                guard let location = response.allHeaderFields["Location"] as? String else {
                    completion(.failure("Failed to get Location from response header for requesting URL: \(url)"))
                    return
                }
                guard let topic = Parser.extractTopic(from: location) else {
                    completion(.failure("Failed to parse topic from absoluteString \(location)"))
                    return
                }
                completion(.success(topic))
            })
    }

    func findPost(urlString: String) async throws -> S1Topic {
        return try await withCheckedThrowingContinuation { continuation in
            findPost(with: urlString) { result in continuation.resume(with: result) }
        }
    }

    @discardableResult
    func findPost(
        withPath referencePath: String,
        completion: @escaping (Result<S1Topic, Error>) -> Void
    ) -> Alamofire.Request {
        return findPost(with: baseURL() + "/" + referencePath, completion: completion)
    }
}
