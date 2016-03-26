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
    private var toolBar: UIToolbar
    private var faceButton: UIButton
    private var spoilerButton: UIButton

    weak var composeViewController: REComposeViewController?
    var mahjongFaceView: S1MahjongFaceView?

    // MARK: - Life Cycle
    init(frame: CGRect, withComposeVC composeVC: REComposeViewController) {
        toolBar = UIToolbar(frame: frame)
        faceButton = UIButton(type: .System)
        spoilerButton = UIButton(type: .System)
        composeViewController = composeVC
        super.init(frame: frame)

        //Setup faceButton
        faceButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        faceButton.setImage(UIImage(named: "MahjongFaceButton"), forState: .Normal)
        faceButton.addTarget(self, action: #selector(ReplyAccessoryView.toggleFace(_:)), forControlEvents: .TouchUpInside)
        let faceItem = UIBarButtonItem(customView: faceButton)

        //Setup spoilerButton
        spoilerButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        spoilerButton.setTitle("H", forState: .Normal)
        spoilerButton.addTarget(self, action: #selector(ReplyAccessoryView.insertSpoilerMark(_:)), forControlEvents: .TouchUpInside)
        let spoilerItem = UIBarButtonItem(customView: spoilerButton)

        //Setup toolBar
        let fixItem = UIBarButtonItem(barButtonSystemItem: .FixedSpace, target: nil, action: nil)
        fixItem.width = 26.0
        let flexItem = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        toolBar.setItems([flexItem, spoilerItem, fixItem, faceItem, flexItem], animated: false)
        self.addSubview(toolBar)
        toolBar.snp_makeConstraints { (make) -> Void in
            make.edges.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let historyArray = self.mahjongFaceView?.historyArray {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                S1DataCenter.sharedDataCenter().mahjongFaceHistoryArray = historyArray
            }
        }
    }

    // MARK: - Actions
    func toggleFace(button: UIButton) {
        guard let composeViewController = composeViewController else {
            return
        }
        if composeViewController.inputView == nil {
            if mahjongFaceView == nil {
                let newMahjongfaceView = S1MahjongFaceView()
                newMahjongfaceView.delegate = self
                newMahjongfaceView.historyCountLimit = 99
                newMahjongfaceView.historyArray = S1DataCenter.sharedDataCenter().mahjongFaceHistoryArray
                mahjongFaceView = newMahjongfaceView
            }
            button.setImage(UIImage(named: "KeyboardButton"), forState: .Normal)
            if let mahjongFaceView = mahjongFaceView {
                composeViewController.inputView = mahjongFaceView
                composeViewController.reloadInputViews()
            }
        } else {
            button.setImage(UIImage(named: "MahjongFaceButton"), forState: .Normal)
            composeViewController.inputView = nil
            composeViewController.reloadInputViews()
        }
    }

    func insertSpoilerMark(button: UIButton) {
        self.insertMarkWithAPart("[color=LemonChiffon]", andBPart: "[/color]")
    }

    func insertQuoteMark(button: UIButton) {
        self.insertMarkWithAPart("[quote]", andBPart: "[/quote]")
    }

    func insertBoldMark(button: UIButton) {
        self.insertMarkWithAPart("[b]", andBPart: "[/b]")
    }

    func insertDeleteMark(button: UIButton) {
        self.insertMarkWithAPart("[s]", andBPart: "[/s]")
    }
}

//MARK: - S1MahjongFaceViewDelegate
extension ReplyAccessoryView: S1MahjongFaceViewDelegate {

    func mahjongFaceViewController(mahjongFaceView: S1MahjongFaceView, didFinishWithResult attachment: S1MahjongFaceTextAttachment) {
        guard let textView = composeViewController?.textView else {
            return
        }
        //Insert Mahjong Face Attachment
        textView.textStorage.insertAttributedString(NSAttributedString(attachment: attachment), atIndex: textView.selectedRange.location)
        //Move selection location
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 1, length: textView.selectedRange.length)
        //Reset Text Style
        ReplyAccessoryView.resetTextViewStyle(textView)
    }

    func mahjongFaceViewControllerDidPressBackSpace(mahjongFaceViewController: S1MahjongFaceView) {
        guard let textView = composeViewController?.textView else {
            return
        }
        var range = textView.selectedRange
        if range.length == 0 && range.location > 0 {
            range.location -= 1
            range.length = 1
        }
        textView.selectedRange = range
        textView.textStorage.deleteCharactersInRange(textView.selectedRange)
        textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
    }
}

// MARK: - Helper
extension ReplyAccessoryView {
    func insertMarkWithAPart(aPart: NSString, andBPart bPart: NSString) {
        guard let textView = composeViewController?.textView else {
            return
        }

        let selectedRange = textView.selectedRange
        let aPartLenght = aPart.length
        if selectedRange.length == 0 {
            let wholeMark = aPart.stringByAppendingString(bPart as String)
            textView.textStorage.insertAttributedString(NSAttributedString(string: wholeMark), atIndex: selectedRange.location)
        } else {
            textView.textStorage.insertAttributedString(NSAttributedString(string: bPart as String), atIndex: selectedRange.location + selectedRange.length)
            textView.textStorage.insertAttributedString(NSAttributedString(string: aPart as String), atIndex: selectedRange.location)
        }
        textView.selectedRange = NSRange(location: selectedRange.location + aPartLenght, length: selectedRange.length)
        ReplyAccessoryView.resetTextViewStyle(textView)
    }

    static func resetTextViewStyle(textView: UITextView) {
        let allTextRange = NSRange(location: 0, length: textView.textStorage.length)
        textView.textStorage.removeAttribute(NSFontAttributeName, range: allTextRange)
        textView.textStorage.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(17.0), range: allTextRange)
        textView.textStorage.removeAttribute(NSForegroundColorAttributeName, range: allTextRange)
        textView.textStorage.addAttribute(NSForegroundColorAttributeName, value: APColorManager.sharedInstance.colorForKey("reply.text"), range: allTextRange)
        textView.font = UIFont.systemFontOfSize(17.0)
        textView.textColor = APColorManager.sharedInstance.colorForKey("reply.text")
    }
}
