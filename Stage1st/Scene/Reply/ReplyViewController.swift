//
//  ReplyViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/6/5.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit

final class ReplyViewController: REComposeViewController {

    let mahjongFaceView = S1MahjongFaceView()
    lazy var replyAccessoryView = {
        ReplyAccessoryView(composeViewController: self)
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        self.accessoryView = replyAccessoryView
        textView.s1_resetToReplyStyle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
