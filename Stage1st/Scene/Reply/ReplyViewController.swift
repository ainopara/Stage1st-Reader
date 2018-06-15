//
//  ReplyViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/5.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit

final class ReplyViewModel {
    enum ReplyTarget {
        case topic
        case floor(Floor, page: Int)
    }
    let topic: S1Topic
    let target: ReplyTarget
    let draft: NSAttributedString?

    init(topic: S1Topic, target: ReplyTarget, draft: NSAttributedString?) {
        self.topic = topic
        self.target = target
        self.draft = draft
    }
}

extension Notification.Name {
    static let ReplyDidPosted = Notification.Name.init(rawValue: "ReplyDidPostedNotification")
}

final class ReplyViewController: REComposeViewController {
    let viewModel: ReplyViewModel

    let mahjongFaceView = S1MahjongFaceView()
    lazy var replyAccessoryView = {
        ReplyAccessoryView(composeViewController: self)
    }()

    init(viewModel: ReplyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        if case let .floor(floor, _) = viewModel.target { // Reply Floor
            title = "@\(floor.author.name)"
        } else { // Reply Topic
            title = NSLocalizedString("ContentViewController.Reply.Title", comment: "Reply")
        }

        if let replyDraft = viewModel.draft {
            textView.attributedText = replyDraft
        }

        self.delegate = self

        self.accessoryView = replyAccessoryView
        textView.s1_resetToReplyStyle()

        mahjongFaceView.delegate = self
        mahjongFaceView.historyCountLimit = 99
        mahjongFaceView.historyArray = AppEnvironment.current.dataCenter.mahjongFaceHistorys
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let historyArray = self.mahjongFaceView.historyArray
        DispatchQueue.global().async {
            AppEnvironment.current.dataCenter.mahjongFaceHistorys = historyArray
        }
    }

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

        mahjongFaceView.backgroundColor = colorManager.colorForKey("mahjongface.background")
        mahjongFaceView.pageControl.pageIndicatorTintColor = colorManager.colorForKey("mahjongface.pagecontrol.indicatortint")
        mahjongFaceView.pageControl.currentPageIndicatorTintColor = colorManager.colorForKey("mahjongface.pagecontrol.currentpage")
    }
}

// MARK: - REComposeViewControllerDelegate

extension ReplyViewController: REComposeViewControllerDelegate {
    func composeViewController(_ composeViewController: REComposeViewController!, didFinishWith result: REComposeResult) {
//        attributedReplyDraft = composeViewController.textView.attributedText.mutableCopy() as? NSMutableAttributedString
        switch result {
        case .cancelled:
            self.replyAccessoryView.removeExtraConstraints()
            self.mahjongFaceView.removeExtraConstraints()

            composeViewController.dismiss(animated: true, completion: nil)
        case .posted:
            guard composeViewController.plainText.count > 0 else {
                return
            }

            let successBlock = { [weak self] in
                MessageHUD.shared.post(message: "回复成功", duration: .second(2.5))
                guard let strongSelf = self else { return }

                NotificationCenter.default.post(name: .ReplyDidPosted, object: nil, userInfo: [
                    "topicID": strongSelf.viewModel.topic.topicID
                ])
            }

            let failureBlock = { (error: Error) in
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
            self.mahjongFaceView.removeExtraConstraints()

            composeViewController.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - S1MahjongFaceViewDelegate

extension ReplyViewController: S1MahjongFaceViewDelegate {
    func mahjongFaceViewController(_: S1MahjongFaceView, didFinishWithResult attachment: S1MahjongFaceTextAttachment) {
        // Insert Mahjong Face Attachment
        textView.textStorage.insert(NSAttributedString(attachment: attachment), at: textView.selectedRange.location)
        // Move selection location
        textView.selectedRange = NSRange(location: textView.selectedRange.location + 1, length: textView.selectedRange.length)
        // Reset Text Style
        textView.s1_resetToReplyStyle()
    }

    func mahjongFaceViewControllerDidPressBackSpace(_: S1MahjongFaceView) {
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
