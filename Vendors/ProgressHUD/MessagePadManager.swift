//
//  ProgressHUD.swift
//  Stage1st
//
//  Created by Zheng Li on 1/11/17.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

class MessagePadManager: UIWindow {
    static var shared = MessagePadManager(frame: .zero)

    let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    let textLabel = UILabel(frame: .zero)

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

        windowLevel = UIWindowLevelStatusBar - 1.0
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
}
