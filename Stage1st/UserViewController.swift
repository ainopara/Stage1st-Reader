//
//  UserViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 3/3/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Result
import ReactiveSwift
import SnapKit
import Kingfisher

final class UserViewController: UIViewController {
    fileprivate let viewModel: UserViewModel

    fileprivate let scrollView = UIScrollView(frame: CGRect.zero)
    fileprivate let containerView = UIView(frame: CGRect.zero)
    fileprivate let avatarView = UIImageView(image: nil) // FIXME: placeholder image.
    fileprivate let usernameLabel = UILabel(frame: CGRect.zero)
    fileprivate let customStatusLabel = UILabel(frame: CGRect.zero)
    fileprivate let infoLabel = UILabel(frame: CGRect.zero)

    // MARK: - Life Cycle
    init(viewModel: UserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
//        self.modalPresentationStyle = .Popover
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")

        self.view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }

        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.edges.equalTo(scrollView) // To decide scrollView's content size
            make.width.equalTo(scrollView.snp.width) // To decide containerView's width
        }

        containerView.addSubview(avatarView)

        avatarView.snp.makeConstraints { (make) in
            make.leading.equalTo(self.containerView.snp.leading).offset(10.0)
            make.top.equalTo(self.containerView.snp.top).offset(10.0)
            make.width.height.equalTo(80.0)
        }

        containerView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.avatarView.snp.top)
            make.leading.equalTo(self.avatarView.snp.trailing).offset(10.0)
            make.trailing.equalTo(self.containerView.snp.trailing).offset(-10)
        }

        customStatusLabel.numberOfLines = 0
        containerView.addSubview(customStatusLabel)
        customStatusLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.usernameLabel.snp.bottom).offset(10.0)
            make.leading.trailing.equalTo(self.usernameLabel)
        }

        infoLabel.numberOfLines = 0
        containerView.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualTo(self.avatarView.snp.bottom).offset(10.0)
            make.top.greaterThanOrEqualTo(self.customStatusLabel.snp.bottom).offset(10.0)
            make.leading.equalTo(avatarView.snp.leading)
            make.trailing.equalTo(usernameLabel.snp.trailing)
        }

        self.viewModel.updateCurrentUserProfile { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .Success(let user):
                strongSelf.usernameLabel.text = user.name
                if let avatarURL = user.avatarURL {
                    strongSelf.avatarView.kf_setImageWithURL(avatarURL)
                }
                strongSelf.customStatusLabel.text = user.customStatus
                strongSelf.infoLabel.attributedText = strongSelf.viewModel.infoLabelAttributedText()
            case .Failure(let error):
                strongSelf.s1_presentAlertView("Error", message: error.description)
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(UserViewController.didReceivePaletteChangeNotification(_:)), name: NSNotification.Name(rawValue: APPaletteDidChangeNotification), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }

}

// MARK: - Style
extension UserViewController {
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return APColorManager.sharedInstance.isDarkTheme() ? .lightContent : .default
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
//        navigationController?.navigationBar.barStyle = APColorManager.sharedInstance.isDarkTheme() ? .Black : .Default
        setNeedsStatusBarAppearanceUpdate()
        view.backgroundColor = APColorManager.sharedInstance.colorForKey("content.background")
    }
}
