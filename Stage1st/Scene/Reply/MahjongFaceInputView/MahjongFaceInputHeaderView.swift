//
//  MahjongFaceInputHeaderView.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/4.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit

final class MahjongFaceInputHeaderView: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .boldSystemFont(ofSize: 14.0)
        addSubview(label)

        label.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.snp.centerY)
            make.leading.equalTo(self.snp.leading).offset(4.0)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
