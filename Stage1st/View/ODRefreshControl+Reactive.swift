//
//  ODRefreshControl+Reactive.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift

extension Reactive where Base: ODRefreshControl {
    var isHidden: BindingTarget<Bool> {
        return makeBindingTarget { $0.isHidden = $1 }
    }
}
