//
//  Cancellable+DisposeBag.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/5.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import RxSwift
import Combine

extension Cancellable {
    func disposed(by bag: DisposeBag) {
        bag.insert(Disposables.create {
            self.cancel()
        })
    }
}
