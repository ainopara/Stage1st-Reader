//
//  ReplyViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/5.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import JTSImageViewController

protocol ReplyViewControllerDraftDelegate: class {
    func replyViewController(_ replyViewController: ReplyViewController, didCancelledWith draft: NSAttributedString)
    func replyViewControllerDidFailed(with draft: NSAttributedString)
}

final class ReplyViewController: REComposeViewController {
    let viewModel: ReplyViewModel

    weak var draftDelegate: ReplyViewControllerDraftDelegate?

    let mahjongFaceInputView = MahjongFaceInputView()
    let replyAccessoryView = ReplyAccessoryView()

    init(viewModel: ReplyViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        switch viewModel.target {
        case .topic:
            title = NSLocalizedString("ContentViewController.Reply.Title", comment: "Reply")
        case .floor(let floor, page: _):
            title = "@\(floor.author.name)"
        }

        self.delegate = self

        self.accessoryView = replyAccessoryView
        textView.s1_resetToReplyStyle()

        replyAccessoryView.delegate = self

//        mahjongFaceView.delegate = self
//        mahjongFaceView.historyCountLimit = 99
//        mahjongFaceView.historyArray = AppEnvironment.current.cacheDatabaseManager.mahjongFaceHistory()

        mahjongFaceInputView.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification(_:)),
            name: .APPaletteDidChange,
            object: nil
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

//        let historyArray = self.mahjongFaceView.historyArray
//        DispatchQueue.global().async {
//            AppEnvironment.current.cacheDatabaseManager.set(mahjongFaceHistory: historyArray)
//        }
    }
}

extension ReplyViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        let colorManager = AppEnvironment.current.colorManager

        textView.keyboardAppearance = colorManager.isDarkTheme() ? .dark : .default
        textView.tintColor = colorManager.colorForKey("reply.tint")
        textView.textColor = colorManager.colorForKey("reply.text")
        sheetBackgroundColor = colorManager.colorForKey("reply.background")

        replyAccessoryView.backgroundColor = colorManager.colorForKey("appearance.toolbar.bartint")
        replyAccessoryView.toolBar.barTintColor = colorManager.colorForKey("appearance.toolbar.bartint")
        replyAccessoryView.toolBar.tintColor = colorManager.colorForKey("appearance.toolbar.tint")

        mahjongFaceInputView.collectionView.backgroundColor = colorManager.colorForKey("reply.background")
        mahjongFaceInputView.collectionView.reloadData()
        mahjongFaceInputView.tabBar.updateColor()
        textView.reloadInputViews()

        navigationBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.bartint")
        navigationBar.tintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.tint")
        navigationBar.titleTextAttributes = [
            .foregroundColor: AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.title"),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ]

        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - REComposeViewControllerDelegate

extension ReplyViewController: REComposeViewControllerDelegate {
    func composeViewController(_ composeViewController: REComposeViewController!, didFinishWith result: REComposeResult) {
        let attributedDraft = composeViewController.textView.attributedText ?? NSAttributedString()
        switch result {
        case .cancelled:
            draftDelegate?.replyViewController(self, didCancelledWith: attributedDraft)

            self.replyAccessoryView.removeExtraConstraints()
//            self.mahjongFaceView.removeExtraConstraints()

            composeViewController.dismiss(animated: true, completion: nil)
        case .posted:
            guard composeViewController.plainText.count > 0 else {
                return
            }

            let topicID = viewModel.topic.topicID

            /// Note: self is supposed to be dealloced when completion block called.
            let successBlock = {
                MessageHUD.shared.post(message: "回复成功", duration: .second(2.5))

                NotificationCenter.default.post(name: .ReplyDidPosted, object: nil, userInfo: [
                    "topicID": topicID
                ])
            }

            weak var theDraftDelegate = self.draftDelegate

            let failureBlock = { (error: Error) in
                theDraftDelegate?.replyViewControllerDidFailed(with: attributedDraft)
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    S1LogDebug("[Network] NSURLErrorCancelled")
                    MessageHUD.shared.post(message: "回复请求取消", duration: .second(1.0))
                } else {
                    S1LogDebug("[Network] reply error: \(error)")
                    MessageHUD.shared.post(message: "回复失败", duration: .second(2.5))
                }
            }
            MessageHUD.shared.post(message: "回复发送中", duration: .forever)

            if case let .floor(floor, page) = viewModel.target {
                AppEnvironment.current.dataCenter.reply(
                    floor: floor,
                    in: viewModel.topic,
                    at: page,
                    text: composeViewController.plainText,
                    successblock: successBlock,
                    failureBlock: failureBlock
                )
            } else {
                AppEnvironment.current.dataCenter.reply(
                    topic: viewModel.topic,
                    text: composeViewController.plainText,
                    successblock: successBlock,
                    failureBlock: failureBlock
                )
            }

            self.replyAccessoryView.removeExtraConstraints()
//            self.mahjongFaceView.removeExtraConstraints()

            composeViewController.dismiss(animated: true, completion: nil)
        }
    }
}

extension ReplyViewController: MahjongFaceInputViewDelegate {
    func mahjongFaceInputView(_ inputView: MahjongFaceInputView, didTapItem item: MahjongFaceInputView.Category.Item) {
        let attachment = S1MahjongFaceTextAttachment()
        attachment.mahjongFaceTag = item.id
        attachment.image = JTSAnimatedGIFUtility.animatedImage(withAnimatedGIFURL: item.url)

        // Insert Mahjong Face Attachment
        textView.textStorage.insert(NSAttributedString(attachment: attachment), at: textView.selectedRange.location)
        // Move selection location
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 1, length: textView.selectedRange.length)
        // Reset Text Style
        textView.s1_resetToReplyStyle()
    }

    func mahjongFaceInputViewDidTapDeleteButton(_ inputView: MahjongFaceInputView) {
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

// MARK: - ReplyAccessoryViewDelegate

extension ReplyViewController: ReplyAccessoryViewDelegate {
    func accessoryView(_ accessoryView: ReplyAccessoryView, didTappedMahjongFaceButton button: UIButton) {
        if self.inputView != nil {
            button.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
//            mahjongFaceView.removeExtraConstraints()
            inputView = nil
            reloadInputViews()
        } else {
            button.setImage(UIImage(named: "KeyboardButton"), for: .normal)
            inputView = mahjongFaceInputView
            reloadInputViews()
        }
    }

    func accessoryView(_ accessoryView: ReplyAccessoryView, didTappedMarkSpoilerButton button: UIButton) {
        insertMarkWithAPart("[color=LemonChiffon]", andBPart: "[/color]")
    }

//    func insertQuoteMark(_: UIButton) {
//        insertMarkWithAPart("[quote]", andBPart: "[/quote]")
//    }
//
//    func insertBoldMark(_: UIButton) {
//        insertMarkWithAPart("[b]", andBPart: "[/b]")
//    }
//
//    func insertDeleteMark(_: UIButton) {
//        insertMarkWithAPart("[s]", andBPart: "[/s]")
//    }
}

// MARK: - Helper

extension ReplyViewController {
    private func insertMarkWithAPart(_ aPart: NSString, andBPart bPart: NSString) {
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

private extension UITextView {
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
