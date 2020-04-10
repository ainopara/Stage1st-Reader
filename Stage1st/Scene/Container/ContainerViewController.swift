//
//  ContainerViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/7/15.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import DeviceKit
import ReactiveSwift
import Combine
import SwiftUI

class ContainerViewController: UIViewController {

    let topicListViewController = TopicListViewController(nibName: nil, bundle: nil)
    lazy var archiveListViewController: S1ArchiveListViewController = { S1ArchiveListViewController(nibName: nil, bundle: nil) }()

    let tabBarState = TabBarState()

    var selectedViewController: CurrentValueSubject<UIViewController, Never>
    var previouslySelectedViewController: UIViewController?
    let scrollTabbar: UIView

    private let pasteboardToast = PasteboardLinkHintToast()

    let pasteboardString = CurrentValueSubject<String, Never>("")
    let pasteboardContainsValidURL = CurrentValueSubject<Bool, Never>(false)

    let pasteboardAnimator = UIViewPropertyAnimator(duration: 0.3, timingParameters: UISpringTimingParameters())

    var bag = Set<AnyCancellable>()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.selectedViewController = CurrentValueSubject(self.topicListViewController)

        let tabBarController = UIHostingController(rootView:
            TabBar(states: tabBarState)
                .environmentObject(AppEnvironment.current.colorManager)
        )

        self.scrollTabbar = tabBarController.view

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Bind ViewModel

        topicListViewController.viewModel.tabBarShouldReset
            .sink { [weak self] in
                guard let self = self else { return }
                self.tabBarState.selectedID = nil
            }
            .store(in: &bag)

        topicListViewController.viewModel.containerShouldSwitchToArchiveList
            .sink { [weak self] in
                guard let self = self else { return }
                self.switchToArchiveList()
            }
            .store(in: &bag)

        AppEnvironment.current.settings.forumBundle.map { try? JSONDecoder().decode(ForumBundle.self, from: $0) }
            .combineLatest(AppEnvironment.current.settings.forumOrderV2.removeDuplicates())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (bundle, order) in
                guard let strongSelf = self else { return }
                guard let bundle = bundle else { return }
                let forums = order.compactMap { id in
                    return bundle.forums.first(where: { forum in forum.id == id })
                }

                strongSelf.tabBarState.selectedID = nil
                strongSelf.tabBarState.dataSource = forums
                strongSelf.topicListViewController.reset()
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: .APPaletteDidChange)
            .sink { [weak self] (notification) in
                guard let self = self else { return }
                self.didReceivePaletteChangeNotification(notification)
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)
            .map { _ in return () }
            .prepend(())
            .map { UIPasteboard.general.string ?? "" }
            .subscribe(pasteboardString)
            .store(in: &bag)

        NotificationCenter.default.publisher(for: UIPasteboard.removedNotification)
            .map { _ in "" }
            .subscribe(pasteboardString)
            .store(in: &bag)

        // Initialize Child View Controller

        applyChildViewControllerSwitch()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubviews()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }
}

// MARK: - Setup

extension ContainerViewController {

    func setupSubviews() {

        view.addSubview(scrollTabbar)

        pasteboardToast.alpha = 0.0
        view.addSubview(pasteboardToast)

        scrollTabbar.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(44.0)
        }
    }

    func setupActions() {
        tabBarState.$selectedID
            .sink { [weak self] (selectedID) in
                guard let strongSelf = self else { return }
                guard let selectedID = selectedID else { return }
                if strongSelf.selectedViewController.value === strongSelf.topicListViewController {
                    strongSelf.topicListViewController.switchToPresenting(key: selectedID)
                } else if strongSelf.selectedViewController.value === strongSelf.archiveListViewController {
                    strongSelf.switchToTopicList()
                    strongSelf.topicListViewController.switchToPresentingKeyIfChanged(key: selectedID)
                } else {
                    assertionFailure("Unknown selectedViewController \(strongSelf.selectedViewController.value)")
                }
            }
            .store(in: &bag)

        pasteboardString
            .map { (string) -> Bool in
                guard string.hasPrefix("http") else { return false }
                for serverAddress in AppEnvironment.current.serverAddress.used where string.hasPrefix(serverAddress) {
                    return true
                }
                return false
            }
            .subscribe(pasteboardContainsValidURL)
            .store(in: &bag)

        pasteboardContainsValidURL
            .removeDuplicates()
            .sink { [weak self] shouldBeShowing in
                guard let strongSelf = self else { return }
                strongSelf.view.layoutIfNeeded()
                if shouldBeShowing {
                    strongSelf.pasteboardAnimator.addAnimations {
                        strongSelf.pasteboardToast.snp.remakeConstraints({ (make) in
                            make.height.equalTo(44.0)
                            make.bottom.equalTo(strongSelf.scrollTabbar.snp.top).offset(-8.0)
                            make.leading.equalTo(strongSelf.view.snp.leading).offset(16.0)
                            make.trailing.equalTo(strongSelf.view.snp.trailing).offset(-16.0)
                        })
                        strongSelf.view.layoutIfNeeded()
                        strongSelf.pasteboardToast.alpha = 1.0
                    }
                } else {
                    strongSelf.pasteboardAnimator.addAnimations {
                        strongSelf.pasteboardToast.snp.remakeConstraints({ (make) in
                            make.height.equalTo(44.0)
                            make.top.equalTo(strongSelf.scrollTabbar.snp.top).offset(8.0)
                            make.leading.equalTo(strongSelf.view.snp.leading).offset(16.0)
                            make.trailing.equalTo(strongSelf.view.snp.trailing).offset(-16.0)
                        })
                        strongSelf.view.layoutIfNeeded()
                        strongSelf.pasteboardToast.alpha = 0.0
                    }
                }
                strongSelf.pasteboardAnimator.startAnimation()
            }
            .store(in: &bag)

        pasteboardToast.button.publisher(for: .touchUpInside)
            .sink { [weak self] event in
                guard let strongSelf = self else { return }

                guard let topic = Parser.extractTopic(from: strongSelf.pasteboardString.value) else {
                    return
                }

                let topicID = topic.topicID
                let processedTopic = AppEnvironment.current.dataCenter.traced(topicID: topicID.intValue) ?? topic
                strongSelf.navigationController?.pushViewController(ContentViewController(topic: processedTopic), animated: true)
                UIPasteboard.general.string = ""
            }
            .store(in: &bag)
    }
}

extension ContainerViewController {

    func switchToTopicList() {
        self.previouslySelectedViewController = self.selectedViewController.value
        self.selectedViewController.value = self.topicListViewController
        applyChildViewControllerSwitch()
    }

    func switchToArchiveList() {
        self.previouslySelectedViewController = self.selectedViewController.value
        self.selectedViewController.value = self.archiveListViewController
        applyChildViewControllerSwitch()
    }

    func applyChildViewControllerSwitch() {
        let current = selectedViewController.value
        let previous = previouslySelectedViewController

        // Suggested by https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/ImplementingaContainerViewController.html
        self.addChild(current)
        self.view.insertSubview(current.view, at: 0) // child view controller's view should always be covered by tab bar.
        current.view.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalTo(self.view)
            make.bottom.equalTo(self.scrollTabbar.snp.top)
        }
        current.didMove(toParent: self)

        previous?.willMove(toParent: nil)
        previous?.view.removeFromSuperview()
        previous?.removeFromParent()
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.selectedViewController.value
    }

    override var childForStatusBarHidden: UIViewController? {
        return self.selectedViewController.value
    }
}

// MARK: - S1TabBarDelegate

extension ContainerViewController: S1TabBarDelegate {
    func tabbar(_ tabbar: S1TabBar, didSelectedKey key: Int) {
        if selectedViewController.value === self.topicListViewController {
            self.topicListViewController.switchToPresenting(key: key)
        } else if selectedViewController.value === self.archiveListViewController {
            self.switchToTopicList()
            self.topicListViewController.switchToPresentingKeyIfChanged(key: key)
        } else {
            S1FatalError("Unknown selectedViewController \(self.selectedViewController.value)")
        }
    }
}

// MARK: - PlatteChange

extension ContainerViewController {
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        pasteboardToast.button.setTitleColor(AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint"), for: .normal)
        pasteboardToast.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        scrollTabbar.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
    }
}

private class PasteboardLinkHintToast: UIView {
    let button = UIButton()

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        layer.cornerRadius = 8.0
        addSubview(button)

        button.setTitle(NSLocalizedString("ContainerViewController.PasteboardLintHint.title", comment: ""), for: .normal)

        button.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
