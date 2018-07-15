//
//  S1TabBar+Reactive.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import ReactiveSwift

extension S1TabBar {
    enum Selection: Equatable {
        case none
        case key(String)
    }
}

extension Reactive where Base: S1TabBar {
    var selection: BindingTarget<S1TabBar.Selection> {
        return makeBindingTarget { (tabBar, selection) in
            switch selection {
            case .none:
                tabBar.deselectAll()
            case .key(let name):
                if let index = tabBar.keys.index(of: name) {
                    tabBar.setSelectedIndex(index)
                } else {
                    fatalError("Could not found key \(name) in \(tabBar.keys)")
                }
            }
        }
    }

    var enabled: BindingTarget<Bool> {
        return makeBindingTarget { $0.enabled = $1 }
    }
}
