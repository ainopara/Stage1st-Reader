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
    init(frame: CGRect, withComposeViewController composeViewController: REComposeViewController) {
        toolBar = UIToolbar(frame: frame)
        faceButton = UIButton(type: .system)
        spoilerButton = UIButton(type: .system)
        self.composeViewController = composeViewController
        super.init(frame: frame)

        //Setup faceButton
        faceButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        faceButton.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
        faceButton.addTarget(self, action: #selector(ReplyAccessoryView.toggleFace(_:)), for: .touchUpInside)
        let faceItem = UIBarButtonItem(customView: faceButton)

        //Setup spoilerButton
        spoilerButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        spoilerButton.setTitle("H", for: .normal)
        spoilerButton.addTarget(self, action: #selector(ReplyAccessoryView.insertSpoilerMark(_:)), for: .touchUpInside)
        let spoilerItem = UIBarButtonItem(customView: spoilerButton)

        //Setup toolBar
        let fixItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixItem.width = 26.0
        let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([flexItem, spoilerItem, fixItem, faceItem, flexItem], animated: false)
        self.addSubview(toolBar)
        toolBar.snp.makeConstraints { (make) -> Void in
            make.edges.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let historyArray = self.mahjongFaceView?.historyArray {
            DispatchQueue.global().async {
                S1DataCenter.shared().mahjongFaceHistoryArray = historyArray
            }
        }
    }
}

// MARK: - Actions
extension ReplyAccessoryView {
    func toggleFace(_ button: UIButton) {
        guard let composeViewController = composeViewController else {
            return
        }
        if composeViewController.inputView == nil {
            if mahjongFaceView == nil {
                let newMahjongfaceView = S1MahjongFaceView()
                newMahjongfaceView.delegate = self
                newMahjongfaceView.historyCountLimit = 99
                newMahjongfaceView.historyArray = S1DataCenter.shared().mahjongFaceHistoryArray ?? [MahjongFaceItem]()
                mahjongFaceView = newMahjongfaceView
            }
            button.setImage(UIImage(named: "KeyboardButton"), for: .normal)
            if let mahjongFaceView = mahjongFaceView {
                composeViewController.inputView = mahjongFaceView
                composeViewController.reloadInputViews()
            }
        } else {
            button.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
            composeViewController.inputView = nil
            composeViewController.reloadInputViews()
        }
    }

    func insertSpoilerMark(_ button: UIButton) {
        self.insertMarkWithAPart("[color=LemonChiffon]", andBPart: "[/color]")
    }

    func insertQuoteMark(_ button: UIButton) {
        self.insertMarkWithAPart("[quote]", andBPart: "[/quote]")
    }

    func insertBoldMark(_ button: UIButton) {
        self.insertMarkWithAPart("[b]", andBPart: "[/b]")
    }

    func insertDeleteMark(_ button: UIButton) {
        self.insertMarkWithAPart("[s]", andBPart: "[/s]")
    }
}

//MARK: - S1MahjongFaceViewDelegate
extension ReplyAccessoryView: S1MahjongFaceViewDelegate {

    func mahjongFaceViewController(_ mahjongFaceView: S1MahjongFaceView, didFinishWithResult attachment: S1MahjongFaceTextAttachment) {
        guard let textView = composeViewController?.textView else {
            return
        }
        //Insert Mahjong Face Attachment
        textView.textStorage.insert(NSAttributedString(attachment: attachment), at: textView.selectedRange.location)
        //Move selection location
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 1, length: textView.selectedRange.length)
        //Reset Text Style
        ReplyAccessoryView.resetTextViewStyle(textView)
    }

    func mahjongFaceViewControllerDidPressBackSpace(_ mahjongFaceViewController: S1MahjongFaceView) {
        guard let textView = composeViewController?.textView else {
            return
        }
        var range = textView.selectedRange
        if range.length == 0 && range.location > 0 {
            range.location -= 1
            range.length = 1
        }
        textView.selectedRange = range
        textView.textStorage.deleteCharacters(in: textView.selectedRange)
        textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
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
        ReplyAccessoryView.resetTextViewStyle(textView)
    }

    static func resetTextViewStyle(_ textView: UITextView) {
        let allTextRange = NSRange(location: 0, length: textView.textStorage.length)
        textView.textStorage.removeAttribute(NSFontAttributeName, range: allTextRange)
        textView.textStorage.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: 17.0), range: allTextRange)
        textView.textStorage.removeAttribute(NSForegroundColorAttributeName, range: allTextRange)
        textView.textStorage.addAttribute(NSForegroundColorAttributeName, value: APColorManager.sharedInstance.colorForKey("reply.text"), range: allTextRange)
        textView.font = UIFont.systemFont(ofSize: 17.0)
        textView.textColor = APColorManager.sharedInstance.colorForKey("reply.text")
    }
}
