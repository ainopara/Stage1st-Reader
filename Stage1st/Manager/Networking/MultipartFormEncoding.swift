//
//  MultipartFormEncoding.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/12/22.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Alamofire

public struct MultipartFormEncoding: ParameterEncoding {
    public static var `default`: MultipartFormEncoding { return MultipartFormEncoding() }

    public init() {}

    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        guard let parameters = parameters else { return urlRequest }

        let formData = MultipartFormData()

        for (key, value) in parameters {
            if let valueData = "\(value)".data(using: .utf8, allowLossyConversion: false) {
                formData.append(valueData, withName: key)
            } else {
                assert(false)
            }
        }

        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        }

        urlRequest.httpBody = try formData.encode()

        return urlRequest
    }
}
