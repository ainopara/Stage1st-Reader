//
//  AllLoadedFooterView.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import ReactiveSwift
import ReactiveCocoa

extension Reactive where Base: UILabel {
    public var font: BindingTarget<UIFont> {
        return makeBindingTarget { $0.font = $1 }
    }
}

class MessageFooterView: UIView {
    private let label = UILabel()

    let message = MutableProperty("")
    let textColor = MutableProperty(UIColor.black)
    let textFont = MutableProperty(UIFont.systemFont(ofSize: 16.0))

    init() {
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 40.0))

        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.leading.equalTo(self.snp.leading).offset(10.0)
            make.trailing.equalTo(self.snp.trailing).offset(-10.0)
            make.centerY.equalTo(self.snp.centerY)
        }

        bindViewModel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    func bindViewModel() {
        label.reactive.text <~ message.skipRepeats()
        label.reactive.textColor <~ textColor.skipRepeats()
        label.reactive.font <~ textFont.skipRepeats()
    }
}
