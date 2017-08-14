//
//  TopicListHeaderView.swift
//  Stage1st
//
//  Created by Zheng Li on 14/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import SnapKit

final class TopicListHeaderView: UITableViewHeaderFooterView {
    let label = UILabel(frame: .zero)

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        // https://stackoverflow.com/questions/15604900/uitableviewheaderfooterview-unable-to-change-background-color
        backgroundView = UIView()

        label.font = UIFont.systemFont(ofSize: 12.0)
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.leading.equalTo(contentView.snp.leading).offset(20.0)
            make.top.bottom.trailing.equalTo(contentView)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
