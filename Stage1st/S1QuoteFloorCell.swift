//
//  S1QuoteFloorCell.swift
//  Stage1st
//
//  Created by Zheng Li on 1/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

class S1QuoteFloorCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var authorLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        initializeCell()
    }
    
    func initializeCell() {
        self.backgroundColor = APColorManager.sharedInstance.colorForKey("content.webview.background")
    }
    
    func updateWithViewModel(viewModel: FloorViewModel) {
        authorLabel.attributedText = viewModel.author
        label.attributedText = viewModel.attributeContent
    }
}
