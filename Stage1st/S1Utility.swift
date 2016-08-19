//
//  S1Utility.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import UIKit

func ensureMainThread(block: () -> Void) {
    if NSThread.currentThread().isMainThread {
        block()
    } else {
        dispatch_async(dispatch_get_main_queue(), {
            block()
        })
    }
}

class S1Utility: NSObject {
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

extension NSDate {
    func s1_gracefulDateTimeString() -> String {
        let interval = -self.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 60 * 60 { return "\(UInt(interval / 60.0))分钟前" }
        if interval < 60 * 60 * 2 { return "1小时前" }
        if interval < 60 * 60 * 3 { return "2小时前" }
        if interval < 60 * 60 * 4 { return "3小时前" }

        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-M-d"
        if formatter.stringFromDate(self) == formatter.stringFromDate(NSDate(timeIntervalSinceNow: 0.0)) {
            formatter.dateFormat = "HH:mm"
            return formatter.stringFromDate(self)
        }
        if formatter.stringFromDate(self) == formatter.stringFromDate(NSDate(timeIntervalSinceNow: -60 * 60 * 24.0)) {
            formatter.dateFormat = "昨天HH:mm"
            return formatter.stringFromDate(self)
        }
        if formatter.stringFromDate(self) == formatter.stringFromDate(NSDate(timeIntervalSinceNow: -60 * 60 * 24 * 2.0)) {
            formatter.dateFormat = "前天HH:mm"
            return formatter.stringFromDate(self)
        }
        formatter.dateFormat = "yyyy"
        if formatter.stringFromDate(self) == formatter.stringFromDate(NSDate(timeIntervalSinceNow: 0.0)) {
            formatter.dateFormat = "M-d HH:mm"
            return formatter.stringFromDate(self)
        }
        formatter.dateFormat = "yyyy-M-d HH:mm"
        return formatter.stringFromDate(self)
    }
}

extension UIView {
    func s1_screenShot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.mainScreen().scale)
        guard let currentContext = UIGraphicsGetCurrentContext() else {
            return nil
        }

        self.layer.renderInContext(currentContext)
        let viewScreenShot: UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return viewScreenShot
    }

    func s1_screenShot(rect: CGRect) -> UIImage? {
        guard let
            originalScreenShot = self.s1_screenShot(),
            processingCGImage = CGImageCreateWithImageInRect(originalScreenShot.CGImage, rect) else {
            return nil
        }
        return UIImage(CGImage: processingCGImage, scale: 1.0, orientation: originalScreenShot.imageOrientation)
    }
    // TODO:
    //    - (UIImage *)screenShot {
    //    //clip
    //    CGImageRef imageRef = CGImageCreateWithImageInRect([viewImage CGImage], CGRectMake(0.0, 20.0 * viewImage.scale, viewImage.size.width * viewImage.scale, viewImage.size.height * viewImage.scale - 20.0 * viewImage.scale));
    //    viewImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:viewImage.imageOrientation];
    //    CGImageRelease(imageRef);
    //    return viewImage;
    //    }
}

extension UIViewController {
    func s1_presentAlertView(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let defaultAction = UIAlertAction(title: NSLocalizedString("Message_OK", comment: "OK"), style: .Default, handler: nil)
        alert.addAction(defaultAction)
        self.presentViewController(alert, animated:true, completion:nil)
    }
}

extension UIWebView {
    func s1_positionOfElementWithId(elementID: String) -> CGRect? {
        let script = "function f(){ var r = document.getElementById('\(elementID)').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();"
        if let result = self.stringByEvaluatingJavaScriptFromString(script) {
            let rect = CGRectFromString(result)
            return rect == CGRect.zero ? nil : rect
        } else {
            return nil
        }
    }

    func s1_atBottom() -> Bool {
        let offsetY = self.scrollView.contentOffset.y
        let maxOffsetY = self.scrollView.contentSize.height - self.bounds.size.height
        return offsetY >= maxOffsetY
    }
}

extension UIImage {
    func s1_tintWithColor(color: UIColor) -> UIImage {
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

extension CGFloat {
    func limit(from: CGFloat, to: CGFloat) -> CGFloat {
        assert(to >= from)
        let result = self < to ? self : to
        return result > from ? result : from
    }
}
