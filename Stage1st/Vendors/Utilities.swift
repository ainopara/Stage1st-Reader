//
//  S1Utility.swift
//  Stage1st
//
//  Created by Zheng Li on 3/26/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import WebKit
import KissXML

func ensureMainThread(_ block: @escaping () -> Void) {
    if Thread.current.isMainThread {
        block()
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
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
        if interval < 60 * 60 { return "\(Int(interval / 60.0))分钟前" }
        if interval < 60 * 60 * 2 { return "1小时前" }
        if interval < 60 * 60 * 3 { return "2小时前" }
        if interval < 60 * 60 * 4 { return "3小时前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d"
        let day = formatter.string(from: self)
        if day == formatter.string(from: Date()) {
            formatter.dateFormat = "HH:mm"
        } else if day == formatter.string(from: Date(timeIntervalSinceNow: -60 * 60 * 24.0)) {
            formatter.dateFormat = "昨天HH:mm"
        } else if day == formatter.string(from: Date(timeIntervalSinceNow: -60 * 60 * 24 * 2.0)) {
            formatter.dateFormat = "前天HH:mm"
        } else {
            formatter.dateFormat = "yyyy"
            let year = formatter.string(from: self)
            if year == formatter.string(from: Date()) {
                formatter.dateFormat = "M-d HH:mm"
            } else {
                formatter.dateFormat = "yyyy-M-d HH:mm"
            }
        }

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

    func s1_firstSubview(with clazz: AnyClass) -> UIView? {
        for subview in self.subviews where subview.isKind(of: clazz) {
            return subview
        }

        return nil
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

extension WKWebView {

    func s1_positionOfElement(with ID: String, completion: @escaping (CGRect?) -> Void) {
        assert(Thread.current.isMainThread)
        guard Thread.current.isMainThread else {
            completion(nil)
            return
        }

        let script = "function f(){ var r = document.getElementById('\(ID)').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();"
        evaluateJavaScript(script) { result, error in
            guard error == nil else {
                S1LogWarn("failed to get position of element: \(ID) with error: \(String(describing: error))")
                completion(nil)
                return
            }

            guard let resultString = result as? String else {
                S1LogWarn("failed to get position of element: \(ID) with result: \(String(describing: result))")
                completion(nil)
                return
            }

            completion(NSCoder.cgRect(for: resultString))
        }
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

// From https://github.com/kickstarter/ios-oss/blob/master/Library/String%2BSimpleHTML.swift
extension String {
    public func s1_htmlStripped(trimWhitespace: Bool = true) -> String? {

        guard let data = self.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        let attributedString = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        )

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
    static func s1_array(fromJSONFileURL jsonFileURL: URL) -> [Element]? {
        guard let jsonString = try? String(contentsOf: jsonFileURL) else {
            return nil
        }

        return s1_array(fromJSONString: jsonString)
    }

    static func s1_array(fromJSONString jsonString: String) -> [Element]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        return s1_array(fromJSONData: data)
    }

    static func s1_array(fromJSONData jsonData: Data) -> [Element]? {
        do {
            return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [Element]
        } catch {
            return nil
        }
    }
}

// MARK: - Regex

extension String {
    func s1_replace(pattern: String, with template: String) -> String {
        let mutableString = self.mutableCopy() as! NSMutableString
        mutableString.s1_replace(pattern: pattern, with: template)
        return mutableString as String
    }
}

extension NSMutableString {
    @discardableResult
    func s1_replace(pattern: String, with template: String) -> Int {
        do {
            let regex = try NSRegularExpression(
                pattern: pattern,
                options: [.dotMatchesLineSeparators]
            )
            return regex.replaceMatches(
                in: self,
                options: [.reportProgress],
                range: NSRange(location: 0, length: self.length),
                withTemplate: template
            )
        } catch let error {
            assert(false, "Regex Replace error: \(error) when initialize with pattern: \(pattern)")
            S1LogError("Regex Replace error: \(error) when initialize with pattern: \(pattern)")
            return 0
        }
    }
}

extension DDXMLNode {
    var recursiveText: String {
        if self.kind == XMLTextKind {
            return self.stringValue ?? ""
        } else {
            return (children ?? []).map({ $0.recursiveText }).joined()
        }
    }

    var firstText: String? {
        return children?.first(where: { $0.kind == XMLTextKind })?.stringValue
    }

    func elements(for xpath: String) throws -> [DDXMLElement] {
        return try nodes(forXPath: xpath).compactMap({ $0 as? DDXMLElement })
    }
}
