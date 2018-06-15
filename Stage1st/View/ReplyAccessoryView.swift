//
//  ReplyAccessaryView.swift
//  Stage1st
//
//  Created by Zheng Li on 2/12/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

class ReplyAccessoryView: UIView {
    let toolBar = UIToolbar(frame: .zero)
    private let faceButton = UIButton(type: .system)
    private let spoilerButton = UIButton(type: .system)

    weak var composeViewController: ReplyViewController?

    // MARK: - Life Cycle
    init(composeViewController: ReplyViewController) {
        self.composeViewController = composeViewController

        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 35))

        // Setup faceButton
        faceButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        faceButton.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
        faceButton.addTarget(self, action: #selector(ReplyAccessoryView.toggleFace(_:)), for: .touchUpInside)
        let faceItem = UIBarButtonItem(customView: faceButton)

        // Setup spoilerButton
        spoilerButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        spoilerButton.setTitle("H", for: .normal)
        spoilerButton.addTarget(self, action: #selector(ReplyAccessoryView.insertSpoilerMark(_:)), for: .touchUpInside)
        let spoilerItem = UIBarButtonItem(customView: spoilerButton)

        // Setup toolBar
        let fixItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixItem.width = 26.0
        let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([flexItem, spoilerItem, fixItem, faceItem, flexItem], animated: false)
        addSubview(toolBar)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = self.window {
            if #available(iOS 11.0, *) {
                self.snp.remakeConstraints { (make) in
                    let height = 35.0 + window.safeAreaInsets.bottom
                    make.top.lessThanOrEqualTo(window.snp.bottom).offset(-height)
                }
                toolBar.snp.remakeConstraints { (make) in
                    make.leading.trailing.top.equalTo(self)
                    make.height.equalTo(35.0)
                }
            } else {
                // Fallback on earlier versions
                self.snp.remakeConstraints { (make) in
                    make.height.equalTo(35.0)
                }
                toolBar.snp.remakeConstraints { (make) in
                    make.edges.equalTo(self)
                }
            }
        }
    }

    func removeExtraConstraints() {
        if #available(iOS 11.0, *) {
            self.snp.removeConstraints()
        }
    }
}

// MARK: - Actions
extension ReplyAccessoryView {
    @objc func toggleFace(_ button: UIButton) {
        guard let composeViewController = composeViewController else {
            return
        }

        if composeViewController.inputView != nil {
            button.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
            composeViewController.mahjongFaceView.removeExtraConstraints()
            composeViewController.inputView = nil
            composeViewController.reloadInputViews()
        } else {
            button.setImage(UIImage(named: "KeyboardButton"), for: .normal)
            composeViewController.inputView = composeViewController.mahjongFaceView
            composeViewController.reloadInputViews()
        }
    }

    @objc func insertSpoilerMark(_: UIButton) {
        insertMarkWithAPart("[color=LemonChiffon]", andBPart: "[/color]")
    }

    func insertQuoteMark(_: UIButton) {
        insertMarkWithAPart("[quote]", andBPart: "[/quote]")
    }

    func insertBoldMark(_: UIButton) {
        insertMarkWithAPart("[b]", andBPart: "[/b]")
    }

    func insertDeleteMark(_: UIButton) {
        insertMarkWithAPart("[s]", andBPart: "[/s]")
    }
}

// MARK: - Helper
extension ReplyAccessoryView {
    func insertMarkWithAPart(_ aPart: NSString, andBPart bPart: NSString) {
        guard let textView = composeViewController?.textView else {
            return
        }

        let selectedRange = textView.selectedRange
        let aPartLenght = aPart.length
        if selectedRange.length == 0 {
            let wholeMark = aPart.appending(bPart as String)
            textView.textStorage.insert(NSAttributedString(string: wholeMark), at: selectedRange.location)
        } else {
            textView.textStorage.insert(NSAttributedString(string: bPart as String), at: selectedRange.location + selectedRange.length)
            textView.textStorage.insert(NSAttributedString(string: aPart as String), at: selectedRange.location)
        }
        textView.selectedRange = NSRange(location: selectedRange.location + aPartLenght, length: selectedRange.length)
        textView.s1_resetToReplyStyle()
    }
}

extension UITextView {
    func s1_resetToReplyStyle() {
        let allTextRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.font, range: allTextRange)
        textStorage.addAttribute(.font, value: UIFont.systemFont(ofSize: 17.0), range: allTextRange)
        textStorage.removeAttribute(.foregroundColor, range: allTextRange)
        textStorage.addAttribute(.foregroundColor, value: AppEnvironment.current.colorManager.colorForKey("reply.text"), range: allTextRange)
        font = UIFont.systemFont(ofSize: 17.0)
        textColor = AppEnvironment.current.colorManager.colorForKey("reply.text")
    }
}
