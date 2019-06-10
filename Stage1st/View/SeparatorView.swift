//
//  SeparatorView.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/24.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

final class SeparatorView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 1.0 / UIScreen.main.scale)
    }
}
