//
//  ActivityItemProvider.swift
//  Stage1st
//
//  Created by Zheng Li on 10/6/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit

extension UIActivity.ActivityType {
    static let weibo = UIActivity.ActivityType("com.sina.weibo.ShareExtension")
    static let moke2 = UIActivity.ActivityType("com.moke.moke-2.Share")
    static let jidian = UIActivity.ActivityType("me.imtx.NewLime.NewLimeShare")

    static let tweetBot4 = UIActivity.ActivityType("com.tapbots.Tweetbot4.shareextension")
}

class ContentTextActivityItemProvider: UIActivityItemProvider {
    let title: String
    let urlString: String

    override var item: Any {
        guard let activityType = self.activityType else {
            return "\(title) \(urlString)"
        }
        switch activityType {
        case .weibo:
            return UIImage() // Weibo official iOS client only support share image.
        case .postToWeibo, .moke2, .jidian:
            return "\(self.title) #Stage1st Reader# \(urlString)"
        case .postToTwitter, .tweetBot4:
            return "\(self.title) #Stage1st \(urlString)"
        default:
            return "\(title) \(urlString)"
        }
    }

    init(title: String, urlString: String) {
        self.title = title
        self.urlString = urlString
        super.init(placeholderItem: "")
    }
}

class ContentImageActivityItemProvider: UIActivityItemProvider {
    weak var view: UIView?
    let rect: CGRect

    override var item: Any {
        var image: UIImage?
        DispatchQueue.main.sync {
            image = view?.s1_screenShot()?.s1_crop(to: rect)
        }
        return image ?? UIImage()
    }

    init(view: UIView, cropTo rect: CGRect) {
        self.view = view
        self.rect = rect
        super.init(placeholderItem: UIImage())
    }
}
