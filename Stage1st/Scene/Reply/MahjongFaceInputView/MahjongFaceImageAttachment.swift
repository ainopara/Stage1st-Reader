//
//  MahjongFaceImageAttachment.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation

final class MahjongFaceTextAttachment: NSTextAttachment {
    let tag: String

    init(tag: String, image: UIImage?) {
        self.tag = tag
        super.init(data: nil, ofType: nil)
        self.image = image
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
