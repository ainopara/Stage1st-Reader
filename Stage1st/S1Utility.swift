//
//  S1Utility.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

class S1Utility: NSObject {
    class func screenShot(view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.mainScreen().scale)
        guard let currentContext = UIGraphicsGetCurrentContext() else {
            return nil
        }

        view.layer.renderInContext(currentContext)
        let viewScreenShot: UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return viewScreenShot
    }

    class func screenShot(view: UIView, rect: CGRect) -> UIImage? {
        guard let originalScreenShot = self.screenShot(view), processingCGImage = CGImageCreateWithImageInRect(originalScreenShot.CGImage, rect) else {
            return nil
        }
        return UIImage(CGImage: processingCGImage, scale: 1.0, orientation: originalScreenShot.imageOrientation)
    }
    //    - (UIImage *)screenShot {
    //    //clip
    //    CGImageRef imageRef = CGImageCreateWithImageInRect([viewImage CGImage], CGRectMake(0.0, 20.0 * viewImage.scale, viewImage.size.width * viewImage.scale, viewImage.size.height * viewImage.scale - 20.0 * viewImage.scale));
    //    viewImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:viewImage.imageOrientation];
    //    CGImageRelease(imageRef);
    //    return viewImage;
    //    }

    class func valuesAreEqual(value1: AnyObject?, _ value2: AnyObject?) -> Bool {

        if let value1 = value1, value2 = value2 {
            return value1.isEqual(value2)
        }
        if value1 == nil && value2 == nil {
            return true
        }
        return false
    }
}

extension UIViewController {
    func presentAlertView(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let defaultAction = UIAlertAction(title: NSLocalizedString("Message_OK", comment: "OK"), style: .Default, handler: nil)
        alert.addAction(defaultAction)
        self.presentViewController(alert, animated:true, completion:nil)
    }
}

extension UIWebView {
    func atBottom() -> Bool {
        let offsetY = self.scrollView.contentOffset.y
        let maxOffsetY = self.scrollView.contentSize.height - self.bounds.size.height
        return offsetY >= maxOffsetY
    }
}

extension UIImage {
    func tintWithColor(color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.mainScreen().scale)
        color.setFill()
        let rect = CGRect(x: 0.0, y: 0.0, width: self.size.width, height: self.size.height)
        UIRectFill(rect)
        self.drawInRect(rect, blendMode: .SourceIn, alpha: 1.0)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}
