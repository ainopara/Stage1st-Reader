//
//  ActivityItemProvider.swift
//  Stage1st
//
//  Created by Zheng Li on 10/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

extension UIActivityType {
    static let moke2 = UIActivityType("com.moke.moke-2.Share")
}

class ContentTextActivityItemProvider: UIActivityItemProvider {
    let title: String

    override var item: Any {
        guard let activityType = self.activityType else {
            return self.title
        }
        switch activityType {
        case UIActivityType.postToWeibo, UIActivityType.moke2:
            return "\(self.title) #Stage1st Reader# "
        case UIActivityType.postToTwitter:
            return "\(self.title) #Stage1stReader "
        default:
            return self.title
        }
    }

    init(title: String) {
        self.title = title
        super.init(placeholderItem: "")
    }
}

class ContentImageActivityItemProvider: UIActivityItemProvider {
    weak var view: UIView?
    let rect: CGRect

    override var item: Any {
        var image: UIImage?
        DispatchQueue.main.sync {
            image = view?.s1_screenShot()?.s1_crop(to: self.rect)
        }
        return image ?? UIImage()
    }

    init(view: UIView, cropTo rect: CGRect) {
        self.view = view
        self.rect = rect
        super.init(placeholderItem: UIImage())
    }
}
