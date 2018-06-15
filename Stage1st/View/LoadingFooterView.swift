//
//  LoadingFooterView.swift
//  Stage1st
//
//  Created by Zheng Li on 09/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import SnapKit

class LoadingFooterView: UIView {
    let label = UILabel()

    init() {
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 40.0))

        label.text = "Loading..."
        label.font = UIFont.systemFont(ofSize: 16.0)
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.center.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}
