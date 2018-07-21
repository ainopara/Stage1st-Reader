//
//  ReportComposeViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 8/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import ReactiveSwift
import SnapKit
import CocoaLumberjack
import YYKeyboardManager
import TextAttributes

final class ReportComposeViewController: UIViewController {
    let textView = UITextView(frame: .zero, textContainer: nil)
    let loadingHUD = S1HUD(frame: .zero)
    let keyboardManager = YYKeyboardManager.default()
    var textViewBottomConstraint: Constraint?

    let viewModel: ReportComposeViewModel

    init(viewModel: ReportComposeViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("ReportComposeViewController.title", comment: "")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(_dismiss))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(submit))

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self.view)
            self.textViewBottomConstraint = make.bottom.equalTo(self.view.snp.bottom).constraint
        }

        view.addSubview(loadingHUD)
        loadingHUD.snp.makeConstraints { make in
            make.center.equalTo(self.view.snp.center)
        }

        view.layoutIfNeeded()

        // Binding
        viewModel.content <~ textView.reactive.continuousTextValues.map { $0 ?? "" }

        viewModel.canSubmit.producer.startWithValues { [weak self] canSubmit in
            guard let strongSelf = self else { return }
            strongSelf.navigationItem.rightBarButtonItem?.isEnabled = canSubmit
        }

        viewModel.isSubmitting.producer.startWithValues { [weak self] submiting in
            guard let strongSelf = self else { return }
            if submiting {
                strongSelf.loadingHUD.showActivityIndicator()
            } else {
                strongSelf.loadingHUD.hide(withDelay: 0.0)
            }
        }

        keyboardManager.add(self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ReportComposeViewController.didReceivePaletteChangeNotification(_:)),
            name: .APPaletteDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .APPaletteDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        textView.becomeFirstResponder()
        didReceivePaletteChangeNotification(nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        view.endEditing(true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 11.0, *) {
            textView.textContainerInset = UIEdgeInsets(
                top: textView.textContainerInset.top,
                left: view.safeAreaInsets.left,
                bottom: textView.textContainerInset.bottom,
                right: view.safeAreaInsets.right
            )
        }

    }
}

// MARK: - YYKeyboardObserver
extension ReportComposeViewController: YYKeyboardObserver {
    func keyboardChanged(with transition: YYKeyboardTransition) {
        let offset = transition.toFrame.minY - view.frame.maxY

        textViewBottomConstraint?.update(offset: offset)

        UIView.animate(withDuration: transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

// MARK: - Actions
extension ReportComposeViewController {
    @objc func submit() {
        view.endEditing(true)
        MessageHUD.shared.post(message: "举报发送中", duration: .forever)
        viewModel.submit { [weak self] error in
            guard let strongSelf = self else { return }
            if let error = error {
                // FIXME: Alert Error
                S1LogError("Report Submit Error: \(error)")
                MessageHUD.shared.post(message: "举报发送失败", duration: .second(2.5))
            } else {
                MessageHUD.shared.post(message: "举报发送成功", duration: .second(2.5))
                strongSelf.dismiss(animated: true, completion: nil)
            }
        }
    }

    @objc func _dismiss() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Notification
    override func didReceivePaletteChangeNotification(_: Notification?) {
        textView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("report.background")
        textView.tintColor = AppEnvironment.current.colorManager.colorForKey("report.tint")
        textView.textColor = AppEnvironment.current.colorManager.colorForKey("report.text")
        textView.typingAttributes = TextAttributes().font(UIFont.systemFont(ofSize: 15.0)).foregroundColor(AppEnvironment.current.colorManager.colorForKey("report.text")).dictionary
        textView.keyboardAppearance = AppEnvironment.current.colorManager.isDarkTheme() ? .dark : .light

        navigationController?.navigationBar.barStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .black : .default
    }
}

// MARK: - Style
extension ReportComposeViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}
