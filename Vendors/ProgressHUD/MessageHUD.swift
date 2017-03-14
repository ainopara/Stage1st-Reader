//
//  MessageHUD.swift
//  Stage1st
//
//  Created by Zheng Li on 1/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

class MessageHUD: UIWindow {
    static var shared = MessageHUD(frame: .zero)

    let backgroundView = UIVisualEffectView(effect: nil)
    let textLabel = UILabel(frame: .zero)
    let decorationLine = UIView(frame: .zero)

    override init(frame: CGRect) {
        var statusBarFrame = UIApplication.shared.statusBarFrame
        statusBarFrame.size.height = statusBarFrame.height + 44.0
        super.init(frame: statusBarFrame)

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }

        textLabel.textAlignment = .center
        backgroundView.addSubview(textLabel)
        textLabel.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(backgroundView)
            make.height.equalTo(44.0)
        }

        backgroundView.addSubview(decorationLine)
        decorationLine.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(backgroundView)
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
        textLabel.text = message
        if case .second(let time) = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + time) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.hide()
            }
        }
    }

    func hide() {
        isHidden = true
    }

    enum Duration {
        case second(TimeInterval)
        case forever
    }

    func didReceivePaletteChangeNotification(_ notification: Notification?) {
        backgroundView.effect = ColorManager.shared.isDarkTheme() ? UIBlurEffect(style: .light) : UIBlurEffect(style: .extraLight)
        textLabel.textColor = ColorManager.shared.colorForKey("reply.text")
        decorationLine.backgroundColor = ColorManager.shared.colorForKey("reply.text")
    }

    func didReceiveStatusBarFrameWillChangeNotification(_ notification: Notification?) {
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
