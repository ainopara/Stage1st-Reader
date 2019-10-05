//
//  Future+sinkResult.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/5.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Combine

extension Future {
    func sinkResult(_ resultCompletionBlock: @escaping (Result<Output, Failure>) -> Void) -> Cancellable {
        let cancellable = sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                resultCompletionBlock(.failure(error))
            case .finished:
                break
            }
        }, receiveValue: { (output) in
            resultCompletionBlock(.success(output))
        })

        return cancellable
    }
}
