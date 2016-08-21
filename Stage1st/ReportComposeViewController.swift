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
    let topic: S1Topic
    let floor: S1Floor
    let content = MutableProperty("")

    let canSubmit = MutableProperty(false)
    let submiting = MutableProperty(false)

    init(apiManager: DiscuzAPIManager, topic: S1Topic, floor: S1Floor) {
        self.apiManager = apiManager
        self.topic = topic
        self.floor = floor

        canSubmit <~ content.producer.map { $0.characters.count > 0 }.combineLatestWith(submiting.producer).map { $0 && !$1 }
    }

    func submit(completion: (NSError?) -> Void) {
        DDLogDebug("submit")
        guard let forumID = topic.fID, formhash = topic.formhash else {
            return
        }
        submiting.value = true
        apiManager.report("\(topic.topicID)", floorID: "\(floor.floorID)", forumID: "\(forumID)", reason: content.value, formhash: formhash) { [weak self] (error) in
            guard let strongSelf = self else { return }
            strongSelf.submiting.value = false
            completion(error)
        }
    }
}

final class ReportComposeViewController: UIViewController {
    let textView = UITextView(frame: .zero, textContainer: nil)
    let loadingHUD = S1HUD(frame: .zero)
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

        view.addSubview(loadingHUD)
        loadingHUD.snp_makeConstraints { (make) in
            make.center.equalTo(self.view.snp_center)
        }

        view.layoutIfNeeded()

        // Binding
        viewModel.content <~ textView.rac_textSignal().toSignalProducer().map { $0 as! String }.flatMapError { _ in return SignalProducer<String, NoError>.empty }
        viewModel.canSubmit.producer.startWithNext { [weak self] (canSubmit) in
            guard let strongSelf = self else { return }
            strongSelf.navigationItem.rightBarButtonItem?.enabled = canSubmit
        }

        viewModel.submiting.producer.startWithNext { [weak self] (submiting) in
            guard let strongSelf = self else { return }
            if submiting {
                strongSelf.loadingHUD.showActivityIndicator()
            } else {
                strongSelf.loadingHUD.hideWithDelay(0.0)
            }
        }

        keyboardManager.addObserver(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ReportComposeViewController.didReceivePaletteChangeNotification(_:)), name: APPaletteDidChangeNotification, object: nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: APPaletteDidChangeNotification, object: nil)
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
        viewModel.submit { [weak self] (error) in
            guard let strongSelf = self else { return }
            if let error = error {
                // FIXME: Alert Error
                DDLogError("Report Submit Error: \(error)")
            } else {
                strongSelf.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }

    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: - Notification
    override func didReceivePaletteChangeNotification(notification: NSNotification?) {
        textView.backgroundColor = APColorManager.sharedInstance.colorForKey("report.background")
        textView.tintColor = APColorManager.sharedInstance.colorForKey("report.tint")
        textView.textColor = APColorManager.sharedInstance.colorForKey("report.text")
        textView.typingAttributes = TextAttributes().font(UIFont.systemFontOfSize(15.0)).foregroundColor(APColorManager.sharedInstance.colorForKey("report.text")).dictionary
        textView.keyboardAppearance = APColorManager.sharedInstance.isDarkTheme() ? .Dark : .Light

        self.navigationController?.navigationBar.barStyle = APColorManager.sharedInstance.isDarkTheme() ? .Black : .Default
    }
}

// MARK: - Style
extension ReportComposeViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .LightContent : .Default
    }
}
