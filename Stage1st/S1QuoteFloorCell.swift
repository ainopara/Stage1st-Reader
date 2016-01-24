//
//  S1QuoteFloorCell.swift
//  Stage1st
//
//  Created by Zheng Li on 1/20/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import YYText

class S1QuoteFloorCell: UITableViewCell {
    @IBOutlet weak var textView: YYTextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initializeCell()
    }
    
    func initializeCell() {
        textView.editable = false
    }
}
