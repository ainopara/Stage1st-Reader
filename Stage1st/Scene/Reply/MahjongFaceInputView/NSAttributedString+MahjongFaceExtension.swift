//
//  NSAttributedString+MahjongFaceExtension.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/1/6.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import UIKit

extension NSAttributedString {

    @objc func s1_getPlainString() -> String {
        var plainString = self.string as NSString
        var base = 0

        self.enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { (value, range, stop) in
            guard let value = value as? MahjongFaceTextAttachment else {
                return
            }

            plainString = plainString.replacingCharacters(in: NSRange(location: range.location + base, length: range.length), with: value.tag) as NSString
            base += value.tag.count - 1
        }
        return plainString as String
    }
}
