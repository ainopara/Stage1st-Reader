//
//  Hud.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/7/7.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Foundation
import SnapKit
import RxSwift
import RxCocoa

final class Hud: UIView {

    private enum Kind {
        case nothing
        case message
        case refreshButton
        case loadingIndicator
    }
    private var kind: Kind = .nothing

    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private let refreshButton = UIButton(type: .custom)

    private var widthConstraint: Constraint?
    private var heightConstraint: Constraint?

    private var refreshBlock: (() -> Void)?

    private let bag = DisposeBag()

    override init(frame: CGRect) {
        super.init(frame: frame)

        alpha = 0.0
        layer.borderWidth = 1.0 / UIScreen.main.scale
        layer.cornerRadius = 3.0

        loadingIndicator.alpha = 0.0
        loadingIndicator.overrideUserInterfaceStyle = .dark
        addSubview(loadingIndicator)

        messageLabel.font = .systemFont(ofSize: 13.0)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0.0
        addSubview(messageLabel)

        refreshButton.setImage(UIImage(named: "Refresh"), for: .normal)
        refreshButton.alpha = 0.0
        addSubview(refreshButton)

        self.snp.makeConstraints { (make) in
            self.widthConstraint = make.width.greaterThanOrEqualTo(60.0).constraint
            self.heightConstraint = make.height.greaterThanOrEqualTo(60.0).constraint
        }

        loadingIndicator.snp.makeConstraints { (make) in
            make.center.equalTo(self)
        }

        messageLabel.snp.makeConstraints { (make) in
            make.center.equalTo(self)
            make.leading.greaterThanOrEqualTo(self.snp.leading).offset(8.0)
            make.trailing.lessThanOrEqualTo(self.snp.trailing).offset(-8.0)
            make.top.greaterThanOrEqualTo(self.snp.top).offset(4.0)
            make.bottom.lessThanOrEqualTo(self.snp.bottom).offset(-4.0)
        }

        refreshButton.snp.makeConstraints { (make) in
            make.center.equalTo(self)
            make.width.height.equalTo(40.0)
        }

        refreshButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.refreshBlock?()
                strongSelf.hide()
            })
            .disposed(by: bag)

        NotificationCenter.default.rx.notification(.APPaletteDidChange)
            .map { _ -> Void in return }
            .startWith(())
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.layer.borderColor = AppEnvironment.current.colorManager.colorForKey("hud.border").cgColor
                self.backgroundColor = AppEnvironment.current.colorManager.colorForKey("hud.background")
                self.messageLabel.textColor = AppEnvironment.current.colorManager.colorForKey("hud.text")
            })
            .disposed(by: bag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        return .zero
    }
}

// MARK: - Interface

extension Hud {

    func show(message: String) {
        refreshBlock = nil
        kind = .message
        widthConstraint?.deactivate()
        heightConstraint?.deactivate()
        showIfCurrentlyHiding()
        UIView.animate(withDuration: 0.2) {
            self.refreshButton.alpha = 0.0
            self.loadingIndicator.alpha = 0.0
            self.loadingIndicator.stopAnimating()
            self.messageLabel.alpha = 1.0
            self.messageLabel.text = message
            self.layoutIfNeeded()
        }
    }

    func showRefresh(with action: @escaping () -> Void) {
        refreshBlock = nil
        kind = .refreshButton
        showIfCurrentlyHiding()
        widthConstraint?.activate()
        heightConstraint?.activate()
        refreshBlock = action
        UIView.animate(withDuration: 0.2) {
            self.refreshButton.alpha = 0.8
            self.loadingIndicator.alpha = 0.0
            self.loadingIndicator.stopAnimating()
            self.messageLabel.alpha = 0.0
            self.messageLabel.text = ""
            self.layoutIfNeeded()
        }
    }

    func showLoadingIndicator() {
        refreshBlock = nil
        if kind == .loadingIndicator {
            UIView.animate(withDuration: 0.1, animations: {
                self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                self.layoutIfNeeded()
            }, completion: { finished in
                if finished {
                    UIView.animate(withDuration: 0.1) {
                        self.transform = .identity
                    }
                } else {
                    self.transform = .identity
                }
            })
        } else {
            kind = .loadingIndicator
            showIfCurrentlyHiding()
            widthConstraint?.activate()
            heightConstraint?.activate()
            UIView.animate(withDuration: 0.2) {
                self.refreshButton.alpha = 0.0
                self.loadingIndicator.alpha = 1.0
                self.loadingIndicator.startAnimating()
                self.messageLabel.alpha = 0.0
                self.messageLabel.text = ""
                self.layoutIfNeeded()
            }
        }
    }

    func hide(delay: TimeInterval = 0.0) {
        refreshBlock = nil
        UIView.animate(withDuration: 0.2, delay: delay, options: .curveEaseInOut, animations: {
            self.alpha = 0.0
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { finished in
            self.kind = .nothing
        })
    }
}

// MARK: - Helpers

private extension Hud {

    func showIfCurrentlyHiding() {
        if alpha == 0.0 {
            layoutIfNeeded()
            alpha = 0.0
            transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1.0
                self.transform = .identity
            }
        }
    }
}
