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
    let theTabBarController: UIViewController

    var selectedViewController: CurrentValueSubject<UIViewController, Never>
    var previouslySelectedViewController: UIViewController?
    let scrollTabBar: UIView

    private let pasteboardToast = PasteboardLinkHintToast()

    enum PasteboardState: Equatable {
        case emptyOrOtherContent
        case containsURL
        case containsStage1stURL(String)
    }
    let pasteboardChangeCount = CurrentValueSubject<Int, Never>(0)
    let pasteboardState = CurrentValueSubject<PasteboardState, Never>(.emptyOrOtherContent)
    let pasteboardAnimator = UIViewPropertyAnimator(duration: 1.0, timingParameters: UISpringTimingParameters())

    var bag = Set<AnyCancellable>()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.selectedViewController = CurrentValueSubject(self.topicListViewController)

        let tabBarController = UIHostingController(rootView:
            TabBar(states: tabBarState)
                .environmentObject(AppEnvironment.current.colorManager)
        )
        self.theTabBarController = tabBarController
        self.scrollTabBar = tabBarController.view

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
            .sink { [weak self] (bundle, order) in
                guard let strongSelf = self else { return }
                guard let bundle = bundle else { return }
                ensureMainThread {
                    let forums = order.compactMap { id in
                        return bundle.forums.first(where: { forum in forum.id == id })
                    }

                    strongSelf.tabBarState.selectedID = nil
                    strongSelf.tabBarState.dataSource = forums
                    strongSelf.topicListViewController.reset()
                }
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: .APPaletteDidChange)
            .sink { [weak self] (notification) in
                guard let self = self else { return }
                self.didReceivePaletteChangeNotification(notification)
            }
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

        view.addSubview(scrollTabBar)

        pasteboardToast.alpha = 5.0
        view.addSubview(pasteboardToast)

        scrollTabBar.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(44.0)
        }

        pasteboardToast.snp.makeConstraints { make in
            make.height.equalTo(32.0)
            make.width.equalTo(160.0)
            make.bottom.equalTo(self.scrollTabBar.snp.top).offset(-8.0)
            make.leading.equalTo(self.view.snp.trailing).offset(16.0)
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

        if AppEnvironment.current.settings.enableOpenPasteboardLink.value {

            pasteboardChangeCount
                .removeDuplicates()
                .sink { changeCount in
                    S1LogDebug("pastebard changed -> \(changeCount)")
                    if #available(iOS 15.0, *) {
                        UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { [weak self] result in
                            guard let self = self else { return }
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let patternDetected) where patternDetected.contains(\.probableWebURL):
                                    self.pasteboardState.send(.containsURL)
                                case .success, .failure:
                                    self.pasteboardState.send(.emptyOrOtherContent)
                                }
                            }
                        }
                    } else
                    if #available(iOS 14.0, *) {
                        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { [weak self] (result) in
                            guard let self = self else { return }
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let patternDetected) where patternDetected.contains(.probableWebURL):
                                    self.pasteboardState.send(.containsURL)
                                case .success, .failure:
                                    S1LogDebug("Unable to detect a url in pasteboard")
                                    self.pasteboardState.send(.emptyOrOtherContent)
                                }
                            }
                        }
                    } else {
                        // Fallback on earlier versions
                        if UIPasteboard.general.hasStrings {
                            let pasteBoardString = UIPasteboard.general.string ?? ""
                            if self.isValidStage1stLink(for: pasteBoardString) {
                                self.pasteboardState.send(.containsStage1stURL(pasteBoardString))
                            } else {
                                self.pasteboardState.send(.emptyOrOtherContent)
                            }
                        } else {
                            self.pasteboardState.send(.emptyOrOtherContent)
                        }
                    }
                }
                .store(in: &bag)

            pasteboardState
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    let shouldBeShowing: Bool = {
                        switch state {
                        case .containsURL, .containsStage1stURL:
                            return true
                        case .emptyOrOtherContent:
                            return false
                        }
                    }()
                    self.view.layoutIfNeeded()
                    if shouldBeShowing {
                        self.pasteboardAnimator.addAnimations {
                            self.pasteboardToast.snp.remakeConstraints({ (make) in
                                make.height.equalTo(32.0)
                                make.width.equalTo(160.0)
                                make.bottom.equalTo(self.scrollTabBar.snp.top).offset(-8.0)
                                make.trailing.equalTo(self.view.snp.trailing).offset(-8.0)
                            })
                            self.view.layoutIfNeeded()
                            self.pasteboardToast.alpha = 1.0
                        }
                    } else {
                        self.pasteboardAnimator.addAnimations {
                            self.pasteboardToast.snp.remakeConstraints({ (make) in
                                make.height.equalTo(32.0)
                                make.width.equalTo(160.0)
                                make.bottom.equalTo(self.scrollTabBar.snp.top).offset(-8.0)
                                make.leading.equalTo(self.view.snp.trailing).offset(8.0)
                            })
                            self.view.layoutIfNeeded()
                            self.pasteboardToast.alpha = 5.0
                        }
                    }
                    self.pasteboardAnimator.startAnimation()
                }
                .store(in: &bag)

            pasteboardToast.action = { [weak self] in
                guard let self = self else { return }

                var urlString: String = ""

                switch self.pasteboardState.value {
                case .emptyOrOtherContent:
                    urlString = ""
                case .containsURL:
                    let pasteboardString = UIPasteboard.general.string ?? ""
                    if self.isValidStage1stLink(for: pasteboardString) {
                        urlString = pasteboardString
                        self.pasteboardState.send(.containsStage1stURL(pasteboardString))
                    } else {
                        urlString = ""
                        self.pasteboardState.send(.emptyOrOtherContent)
                        let alertController = UIAlertController(title: NSLocalizedString("ContainerViewController.PasteboardAlert.title", comment: ""), message: nil, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("ContainerViewController.PasteboardAlert.OK", comment: ""), style: .default, handler: nil))
                        self.present(alertController, animated: true)
                    }
                case .containsStage1stURL(let stage1stURL):
                    urlString = stage1stURL
                }

                guard let topic = Parser.extractTopic(from: urlString) else {
                    return
                }

                let topicID = topic.topicID
                let processedTopic = AppEnvironment.current.dataCenter.traced(topicID: topicID.intValue) ?? topic
                self.navigationController?.pushViewController(ContentViewController(topic: processedTopic), animated: true)
                UIPasteboard.general.string = ""
            }

            func setupPasteboardChecker() {
                Task {
                    S1LogVerbose("Change count: \(UIPasteboard.general.changeCount)")
                    self.pasteboardChangeCount.send(UIPasteboard.general.changeCount)
                    try await Task.sleep(nanoseconds:1_000_000_000)
                    setupPasteboardChecker()
                }
            }
            setupPasteboardChecker()
        }
    }

    func isValidStage1stLink(for string: String) -> Bool {
        guard string.hasPrefix("http") else { return false }

        let hasValidDomain: Bool = {
            for serverAddress in AppEnvironment.current.serverAddress.used where string.hasPrefix(serverAddress) {
                return true
            }
            return false
        }()

        guard hasValidDomain else { return false }

        guard Parser.extractTopic(from: string) != nil else {
            return false
        }

        return true
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
            make.bottom.equalTo(self.scrollTabBar.snp.top)
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

// MARK: - PlatteChange

extension ContainerViewController {
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
        scrollTabBar.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
    }
}

private class PasteboardLinkHintToast: UIView {

    var hostingControllerHolder: UIViewController?
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let button = PasteboardButton(action: { [weak self] in self?.action?() })
            .environmentObject(AppEnvironment.current.colorManager)
         let hostingController = UIHostingController(rootView: button)
        hostingControllerHolder = hostingController

        addSubview(hostingController.view)

        hostingController.view.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
