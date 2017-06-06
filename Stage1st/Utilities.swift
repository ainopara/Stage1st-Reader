//
//  S1Utility.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import CocoaLumberjack

func ensureMainThread(_ block: @escaping () -> Void) {
    if Thread.current.isMainThread {
        block()
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
}

// https://www.youtube.com/watch?v=jzdOkQFekbg `Let's Talk About Let` by `objc.io`
func mutate<T>(_ value: T, change: (inout T) -> Void) -> T {
    var copy = value
    change(&copy)
    return copy
}

func valuesAreEqual(_ value1: AnyObject?, _ value2: AnyObject?) -> Bool {
    if let value1 = value1, let value2 = value2 {
        return value1.isEqual(value2)
    }

    if value1 == nil && value2 == nil {
        return true
    }

    return false
}

extension Date {
    func s1_isLaterThan(date: Date) -> Bool {
        return compare(date) == .orderedDescending
    }

    func s1_isEarlierThan(date: Date) -> Bool {
        return compare(date) == .orderedAscending
    }
}

extension Date {
    func s1_gracefulDateTimeString() -> String {
        let interval = -timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 60 * 60 { return "\(UInt(interval / 60.0))分钟前" }
        if interval < 60 * 60 * 2 { return "1小时前" }
        if interval < 60 * 60 * 3 { return "2小时前" }
        if interval < 60 * 60 * 4 { return "3小时前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d"
        if formatter.string(from: self) == formatter.string(from: Date(timeIntervalSinceNow: 0.0)) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
        }
        if formatter.string(from: self) == formatter.string(from: Date(timeIntervalSinceNow: -60 * 60 * 24.0)) {
            formatter.dateFormat = "昨天HH:mm"
            return formatter.string(from: self)
        }
        if formatter.string(from: self) == formatter.string(from: Date(timeIntervalSinceNow: -60 * 60 * 24 * 2.0)) {
            formatter.dateFormat = "前天HH:mm"
            return formatter.string(from: self)
        }
        formatter.dateFormat = "yyyy"
        if formatter.string(from: self) == formatter.string(from: Date(timeIntervalSinceNow: 0.0)) {
            formatter.dateFormat = "M-d HH:mm"
            return formatter.string(from: self)
        }
        formatter.dateFormat = "yyyy-M-d HH:mm"
        return formatter.string(from: self)
    }
}

extension UIView {
    func s1_screenShot() -> UIImage? {
        // https://chromium.googlesource.com/chromium/src.git/+/46.0.2478.0/ios/chrome/browser/snapshots/snapshot_manager.mm
        func viewHierarchyContainsWKWebView(_ view: UIView) -> Bool {
            if view is WKWebView {
                return true
            }

            for subview in view.subviews {
                if viewHierarchyContainsWKWebView(subview) {
                    return true
                }
            }

            return false
        }

        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        guard let currentContext = UIGraphicsGetCurrentContext() else {
            return nil
        }

        if viewHierarchyContainsWKWebView(self) {
            drawHierarchy(in: bounds, afterScreenUpdates: true)
        } else {
            layer.render(in: currentContext)
        }

        let viewScreenShot: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return viewScreenShot
    }
}

extension UIViewController {
    func s1_presentAlertView(_ title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: NSLocalizedString("Message_OK", comment: "OK"), style: .default, handler: nil)
        alert.addAction(defaultAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - WebView

extension UIWebView {
    func s1_positionOfElementWithId(_ elementID: String) -> CGRect? {
        let script = "function f(){ var r = document.getElementById('\(elementID)').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();"
        if let result = stringByEvaluatingJavaScript(from: script) {
            let rect = CGRectFromString(result)
            return rect == CGRect.zero ? nil : rect
        } else {
            return nil
        }
    }

    func s1_atBottom() -> Bool {
        let offsetY = scrollView.contentOffset.y
        let maxOffsetY = scrollView.contentSize.height - bounds.size.height
        return offsetY >= maxOffsetY
    }
}

extension WKWebView {
    func s1_positionOfElement(with ID: String) -> CGRect? {
        // TODO: Find a better solution for avoid dead lock.
        assert(!Thread.current.isMainThread)
        guard !Thread.current.isMainThread else {
            return nil
        }

        let script = "function f(){ var r = document.getElementById('\(ID)').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();"
        var rect: CGRect?
        let semaphore = DispatchSemaphore(value: 0)
        evaluateJavaScript(script) { result, error in
            defer {
                semaphore.signal()
            }

            guard error == nil else {
                DDLogWarn("failed to get position of element: \(ID) with error: \(String(describing: error))")
                return
            }

            guard let resultString = result as? String else {
                DDLogWarn("failed to get position of element: \(ID) with result: \(String(describing: result))")
                return
            }

            rect = CGRectFromString(resultString)
        }

        semaphore.wait()
        return rect
    }

    func s1_atBottom() -> Bool {
        let offsetY = scrollView.contentOffset.y
        let maxOffsetY = scrollView.contentSize.height - bounds.size.height
        return offsetY >= maxOffsetY
    }

    func s1_scrollToBottom(animated: Bool) {
        let offset = CGPoint(x: 0.0, y: scrollView.contentSize.height - scrollView.bounds.height)
        scrollView.setContentOffset(offset, animated: animated)
    }
}

// MARK: -

extension UIImage {
    func s1_tintWithColor(_ color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        color.setFill()
        let rect = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        UIRectFill(rect)
        draw(in: rect, blendMode: .sourceIn, alpha: 1.0)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    func s1_crop(to rect: CGRect) -> UIImage? {
        var rect = rect
        let scale = self.scale
        rect.origin.x *= scale
        rect.origin.y *= scale
        rect.size.width *= scale
        rect.size.height *= scale
        if let cgImage = self.cgImage?.cropping(to: rect) {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }
}

// From: https://github.com/apple/swift-evolution/blob/master/proposals/0177-add-clamped-to-method.md
extension Comparable {
    func s1_clamped(to range: ClosedRange<Self>) -> Self {
        if self > range.upperBound {
            return range.upperBound
        } else if self < range.lowerBound {
            return range.lowerBound
        } else {
            return self
        }
    }
}

// From https://github.com/kickstarter/ios-oss/blob/master/Library/String%2BSimpleHTML.swift
extension String {
    public func s1_htmlStripped(trimWhitespace: Bool = true) -> String? {

        guard let data = self.data(using: .utf8) else { return nil }

        let options: [String: Any] = [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue,
        ]

        let attributedString = try? NSAttributedString(data: data,
                                                       options: options,
                                                       documentAttributes: nil)
        let result = attributedString?.string

        if trimWhitespace {
            return result.flatMap { ($0 as NSString).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return result
    }
}

extension Dictionary {
    static func s1_dictionary(from jsonFile: URL) -> [String: Any]? {
        guard let jsonString = try? String(contentsOf: jsonFile) else {
            return nil
        }

        return s1_dictionary(from: jsonString)
    }

    static func s1_dictionary(from jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        return s1_dictionary(from: data)
    }

    static func s1_dictionary(from jsonData: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        } catch {
            return nil
        }
    }
}

extension Array {
    static func s1_array(from jsonFile: URL) -> [Any]? {
        guard let jsonString = try? String(contentsOf: jsonFile) else {
            return nil
        }

        return s1_array(from: jsonString)
    }

    static func s1_array(from jsonString: String) -> [Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        return s1_array(from: data)
    }

    static func s1_array(from jsonData: Data) -> [Any]? {
        do {
            return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [Any]
        } catch {
            return nil
        }
    }
}

// MARK: - Regex

extension String {
    func s1_replace(pattern: String, with template: String) -> String {
        let mutableString = self.mutableCopy() as! NSMutableString
        _ = mutableString.s1_replace(pattern: pattern, with: template)
        return mutableString as String
    }
}

extension NSMutableString {
    func s1_replace(pattern: String, with template: String) -> Int {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            return regex.replaceMatches(in: self, options: [.reportProgress], range: NSMakeRange(0, self.length), withTemplate: template)
        } catch let error {
            DDLogError("Regex Replace error: \(error) when initialize with pattern: \(pattern)")
            return 0
        }
    }
}
