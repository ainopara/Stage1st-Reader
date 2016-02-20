//
//  S1QuoteFloorCell.swift
//  Stage1st
//
//  Created by Zheng Li on 1/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

class S1QuoteFloorCell: UITableViewCell {
    var label: UILabel = UILabel()
    
    var authorLabel: UILabel = UILabel()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = APColorManager.sharedInstance.colorForKey("content.webview.background")

        self.addSubview(self.authorLabel)
        self.authorLabel.snp_makeConstraints { (make) -> Void in
            make.left.right.top.equalTo(self)

        }

        self.label.numberOfLines = 0
        self.addSubview(self.label)
        self.label.snp_makeConstraints { (make) -> Void in
            make.left.right.bottom.equalTo(self)
            make.top.equalTo(self.authorLabel.snp_bottom).offset(1.0)
        }


    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }



    
    func updateWithViewModel(viewModel: FloorViewModel) {
        authorLabel.attributedText = viewModel.author
        label.attributedText = viewModel.attributeContent
    }
}
