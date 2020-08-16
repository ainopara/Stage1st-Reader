//
//  UserViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Combine
import SnapKit
import Kingfisher

final class UserViewController: UIViewController {
    private let viewModel: UserViewModel

    private let scrollView = UIScrollView(frame: .zero)
    private let containerView = UIView(frame: .zero)
    private let avatarView = UIImageView(image: nil) // TODO: Add placeholder image.
    private let usernameLabel = UILabel(frame: .zero)
    private let blockButton = UIButton(type: .system)
    private let customStatusLabel = UILabel(frame: .zero)
    private let infoLabel = UILabel(frame: .zero)

    private var bag = Set<AnyCancellable>()

    // MARK: - Life Cycle
    init(viewModel: UserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.borderWidth = 1.0
        avatarView.layer.cornerRadius = 4.0
        avatarView.clipsToBounds = true
        customStatusLabel.numberOfLines = 0
        infoLabel.numberOfLines = 0

        bindViewModel()

        NotificationCenter.default.publisher(for: .APPaletteDidChange)
            .sink { [weak self] notification in
                guard let strongSelf = self else { return }
                strongSelf.didReceivePaletteChangeNotification(notification)
            }
            .store(in: &bag)

//        viewModel.updateCurrentUserProfile { [weak self] result in
//            guard let strongSelf = self else { return }
//            switch result {
//            case let .success(user):
//                break
//            case let .failure(error):
//                S1LogDebug("Failed to update user profile. error: \(error)")
//                strongSelf.s1_presentAlertView("Error", message: "\(error)")
//            }
//        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindViewModel() {

        viewModel.user
            .sink { [weak self] (user) in
                guard let strongSelf = self else { return }

                if let avatarURL = user.avatarURL {
                    strongSelf.avatarView.kf.setImage(with: avatarURL)
                }
            }
            .store(in: &bag)

        viewModel.username
            .sink { [weak self] in self?.usernameLabel.text = $0 }
            .store(in: &bag)

        viewModel.isBlocked
            .map { $0 ? "解除屏蔽" : "屏蔽" }
            .sink { [weak self] in self?.blockButton.setTitle($0, for: .normal) }
            .store(in: &bag)

        blockButton.publisher(for: .touchUpInside)
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.toggleBlockStatus()
            }
            .store(in: &bag)
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
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }

    override func didReceivePaletteChangeNotification(_: Notification?) {
        let colorManager = AppEnvironment.current.colorManager
        view.backgroundColor = colorManager.colorForKey("content.background")
        usernameLabel.textColor = colorManager.colorForKey("default.text.tint")
        customStatusLabel.textColor = colorManager.colorForKey("default.text.tint")
        infoLabel.textColor = colorManager.colorForKey("default.text.tint")
        avatarView.layer.borderColor = colorManager.colorForKey("user.avatar.border").cgColor
        setNeedsStatusBarAppearanceUpdate()
    }
}
