//
//  ReportComposeViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 8/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Result
import ReactiveCocoa
import SnapKit
import CocoaLumberjack
import YYKeyboardManager
import TextAttributes

final class ReportComposeViewModel {
    let apiManager: DiscuzAPIManager

    init(apiManager: DiscuzAPIManager, topic: S1Topic, floor: S1Floor) {
        self.apiManager = apiManager
    }

    func submit() {
        DDLogDebug("submit")
    }
}

final class ReportComposeViewController: UIViewController {
    let textView = UITextView(frame: .zero, textContainer: nil)
    let keyboardManager = YYKeyboardManager.defaultManager()
    var textViewBottomConstraint: Constraint? = nil

    let viewModel: ReportComposeViewModel

    init(viewModel: ReportComposeViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("ReportComposeViewController.title", comment: "")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(ReportComposeViewController.dismiss))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(ReportComposeViewController.submit))

        view.addSubview(textView)
        textView.snp_makeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.view)
            self.textViewBottomConstraint = make.bottom.equalTo(self.view.snp_bottom).constraint
        }

        view.layoutIfNeeded()

        keyboardManager.addObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ReportComposeViewController.didReceivePaletteChangeNotification(_:)), name: APPaletteDidChangeNotification, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        textView.becomeFirstResponder()
        didReceivePaletteChangeNotification(nil)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        view.endEditing(true)
    }
}

// MARK: - YYKeyboardObserver
extension ReportComposeViewController: YYKeyboardObserver {
    func keyboardChangedWithTransition(transition: YYKeyboardTransition) {
         let offset = transition.toFrame.minY - view.frame.maxY

        self.textViewBottomConstraint?.updateOffset(offset)

        UIView.animateWithDuration(transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

// MARK: - Actions
extension ReportComposeViewController {
    func submit() {
        view.endEditing(true)
        viewModel.submit()
    }

    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: - Notification
    func didReceivePaletteChangeNotification(notification: NSNotification?) {
        textView.backgroundColor = APColorManager.sharedInstance.colorForKey("report.background")
        textView.tintColor = APColorManager.sharedInstance.colorForKey("report.tint")
        textView.textColor = APColorManager.sharedInstance.colorForKey("report.text")
        let attributes = TextAttributes().font(UIFont.systemFontOfSize(15.0)).foregroundColor(APColorManager.sharedInstance.colorForKey("report.text"))
        textView.typingAttributes = attributes.dictionary
        textView.keyboardAppearance = APColorManager.sharedInstance.isDarkTheme() ? .Dark : .Light

        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - Style
extension ReportComposeViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}
