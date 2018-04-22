//
//  UserViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import ReactiveCocoa
import ReactiveSwift
import SnapKit
import AlamofireImage
import CocoaLumberjack

final class UserViewController: UIViewController {
    private let viewModel: UserViewModel

    fileprivate let scrollView = UIScrollView(frame: .zero)
    fileprivate let containerView = UIView(frame: .zero)
    fileprivate let avatarView = UIImageView(image: nil) // TODO: Add placeholder image.
    fileprivate let usernameLabel = UILabel(frame: .zero)
    fileprivate let blockButton = UIButton(type: .system)
    fileprivate let customStatusLabel = UILabel(frame: .zero)
    fileprivate let infoLabel = UILabel(frame: .zero)

    // MARK: - Life Cycle
    init(viewModel: UserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.borderWidth = 1.0 / UIScreen.main.scale
        avatarView.clipsToBounds = true
        customStatusLabel.numberOfLines = 0
        infoLabel.numberOfLines = 0

        bindViewModel()

        viewModel.updateCurrentUserProfile { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case let .success(user):
                strongSelf.customStatusLabel.text = user.customStatus
                strongSelf.infoLabel.text = strongSelf.viewModel.infoLabelText()
            case let .failure(error):
                S1LogDebug("Failed to update user profile. error: \(error)")
//                strongSelf.s1_presentAlertView("Error", message: "\(error)")
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(UserViewController.didReceivePaletteChangeNotification(_:)),
            name: .APPaletteDidChange,
            object: nil
        )
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func bindViewModel() {
        viewModel.avatarURL.producer.startWithValues { [weak self] (url) in
            guard let strongSelf = self else { return }

            if let avatarURL = url {
                strongSelf.avatarView.af_setImage(withURL: avatarURL)
            }
        }

        usernameLabel.reactive.text <~ viewModel.username

        viewModel.isBlocked.producer.startWithValues { [weak self] isBlocked in
            guard let strongSelf = self else { return }
            strongSelf.blockButton.setTitle(isBlocked ? "解除屏蔽" : "屏蔽", for: .normal)
        }

        blockButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.viewModel.toggleBlockStatus()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView) // To decide scrollView's content size
            make.width.equalTo(scrollView.snp.width) // To decide containerView's width
        }

        containerView.addSubview(avatarView)

        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(containerView.snp.leading).offset(10.0)
            make.top.equalTo(containerView.snp.top).offset(10.0)
            make.width.height.equalTo(80.0)
        }

        containerView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarView.snp.top)
            make.leading.equalTo(avatarView.snp.trailing).offset(10.0)
        }

        blockButton.setContentHuggingPriority(UILayoutPriority(UILayoutPriority.defaultLow.rawValue + 1.0), for: .horizontal)
        containerView.addSubview(blockButton)
        blockButton.snp.makeConstraints { make in
            make.leading.equalTo(usernameLabel.snp.trailing).offset(10.0)
            make.trailing.equalTo(containerView.snp.trailing).offset(-10.0)
            make.top.equalTo(usernameLabel.snp.top)
            make.bottom.equalTo(usernameLabel.snp.bottom)
        }

        containerView.addSubview(customStatusLabel)
        customStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(usernameLabel.snp.bottom).offset(10.0)
            make.leading.equalTo(usernameLabel.snp.leading)
            make.trailing.equalTo(blockButton.snp.trailing)
        }

        containerView.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(avatarView.snp.bottom).offset(10.0)
            make.top.greaterThanOrEqualTo(customStatusLabel.snp.bottom).offset(10.0)
            make.leading.equalTo(avatarView.snp.leading)
            make.trailing.equalTo(blockButton.snp.trailing)
            make.bottom.equalTo(containerView.snp.bottom).offset(-10.0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }
}

// MARK: - Style
extension UserViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
    }

    override func didReceivePaletteChangeNotification(_: Notification?) {
        view.backgroundColor = ColorManager.shared.colorForKey("content.background")
        usernameLabel.textColor = ColorManager.shared.colorForKey("default.text.tint")
        customStatusLabel.textColor = ColorManager.shared.colorForKey("default.text.tint")
        infoLabel.textColor = ColorManager.shared.colorForKey("default.text.tint")
        setNeedsStatusBarAppearanceUpdate()
    }
}
