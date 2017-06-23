//
//  MessageHUD.swift
//  Stage1st
//
//  Created by Zheng Li on 1/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjack

class MessageHUD: UIWindow {
    enum State {
        case hidden
        case appearing
        case presenting
        case hiding
    }
    static var shared = MessageHUD(frame: .zero)

    let backgroundView = UIVisualEffectView(effect: nil)
    let textLabel = UILabel(frame: .zero)
    let decorationLine = UIView(frame: .zero)
    var state: State = .hidden { didSet {
        print(state)
        }
    }
    var currentHidingToken = ""

    override init(frame: CGRect) {
        var statusBarFrame = UIApplication.shared.statusBarFrame
        statusBarFrame.size.height = statusBarFrame.height + 44.0
        super.init(frame: statusBarFrame)

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }

        textLabel.textAlignment = .center
        backgroundView.contentView.addSubview(textLabel)
        textLabel.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(backgroundView.contentView)
            make.height.equalTo(44.0)
        }

        addSubview(decorationLine)
        decorationLine.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(self)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        windowLevel = UIWindowLevelStatusBar - 1.0

        didReceivePaletteChangeNotification(nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceiveStatusBarFrameWillChangeNotification(_:)),
                                               name: .UIApplicationWillChangeStatusBarFrame,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceivePaletteChangeNotification(_:)),
                                               name: .APPaletteDidChangeNotification,
                                               object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func post(message: String, duration: Duration = .forever, animated: Bool = true) {
        makeKeyAndVisible()
        switch state {
        case .presenting:
            textLabel.text = message
            hide(after: duration, animated: animated)
        case .hidden:
            textLabel.text = message
            isHidden = false
            if animated {
                self.state = .appearing
                UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 10.0, options: [], animations: {
                    self.alpha = 1.0
                }) { [weak self] (_) in
                    guard let strongSelf = self else { return }
                    strongSelf.state = .presenting
                    strongSelf.hide(after: duration, animated: animated)
                }
            } else {
                self.alpha = 1.0
                self.state = .presenting
                hide(after: duration, animated: animated)
            }
        default:
            DDLogError("missed \(state)")
        }
    }

    private func hide(after duration: Duration, animated: Bool) {
        if case .second(let time) = duration {
            let token = UUID().uuidString
            self.currentHidingToken = token
            DispatchQueue.main.asyncAfter(deadline: .now() + time) { [weak self] in
                guard let strongSelf = self else { return }
                guard strongSelf.currentHidingToken == token else { return }
                strongSelf.hide(animated: animated)
            }
        }
    }

    func hide(animated: Bool = true) {
        guard state == .presenting || state == .appearing else {
            DDLogWarn("Ignoring message hud hide operation with state: \(state)")
            return
        }

        currentHidingToken = ""

        if animated {
            self.state = .hiding
            UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [], animations: {
                self.alpha = 0.0
            }, completion: { [weak self] (_) in
                guard let strongSelf = self else { return }
                strongSelf.state = .hidden
                strongSelf.isHidden = true
            })
        } else {
            self.alpha = 0.0
            state = .hidden
            isHidden = true
        }
    }

    enum Duration {
        case second(TimeInterval)
        case forever
    }

    @objc func didReceivePaletteChangeNotification(_ notification: Notification?) {
        backgroundView.effect = ColorManager.shared.isDarkTheme() ? UIBlurEffect(style: .light) : UIBlurEffect(style: .extraLight)
        textLabel.textColor = ColorManager.shared.colorForKey("reply.text")
        decorationLine.backgroundColor = ColorManager.shared.colorForKey("reply.text")
    }

    @objc func didReceiveStatusBarFrameWillChangeNotification(_ notification: Notification?) {
        guard let newFrame = notification?.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? CGRect else {
            return
        }

        let finalFrame = mutate(newFrame) { (value: inout CGRect) in
            value.size.height += 44.0
        }

        UIView.animate(withDuration: 0.3) {
            self.frame = finalFrame
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}
