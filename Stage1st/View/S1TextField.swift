//
//  S1TextField.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/6/24.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import UIKit

final class S1TextField: UITextField {

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 16.0, dy: 0.0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 16.0, dy: 0.0)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 16.0, dy: 0.0)
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 44.0)
    }
}
