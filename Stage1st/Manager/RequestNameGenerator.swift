//
//  RequestNameGenerator.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/9/30.
//  Copyright © 2019 Renaissance. All rights reserved.
//

#if DEBUG

import Foundation
import CryptoKit
import CommonCrypto

final class RequestNameGenerator {
    static func name(for request: URLRequest) -> String {
        let urlData = (request.url?.absoluteString ?? "").data(using: .utf8) ?? Data()
        let bodyData = request.httpBody ?? Data()

        let requestData = urlData + bodyData

        if #available(iOS 13.0, *) {
            return SHA256.hash(data: requestData).hexEncodedString()
        } else {
            return sha256(data: requestData).hexEncodedString()
        }
    }
}

private extension Sequence where Element == UInt8 {
    func hexEncodedString() -> String {
        return map { byte in String(format: "%02hhx", byte) }.joined()
    }
}

private func sha256(data: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

#endif
