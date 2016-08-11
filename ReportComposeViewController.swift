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

final class ReportComposeViewController: UIViewController {
    let textView = UITextView(frame: .zero, textContainer: nil)
    let keyboardManager = YYKeyboardManager.defaultManager()
    var textViewBottomConstraint: Constraint? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(textView)
        textView.snp_makeConstraints { (make) in
            make.leading.trailing.equalTo(self.view)
            make.top.equalTo(self.snp_topLayoutGuideBottom)
            self.textViewBottomConstraint = make.bottom.equalTo(self.view.snp_bottom).constraint
        }

        keyboardManager.addObserver(self)
    }
}

extension ReportComposeViewController: YYKeyboardObserver {
    func keyboardChangedWithTransition(transition: YYKeyboardTransition) {

        self.textViewBottomConstraint?.updateOffset(transition.toFrame.height)

        UIView.animateWithDuration(transition.animationDuration, delay: 0.0, options: transition.animationOption, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}
