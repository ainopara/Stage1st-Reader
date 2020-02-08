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

protocol ContainerDelegate: class {
    func containerViewControllerShouldSelectTabButton(at index: Int)
    func containerViewControllerShouldDeselectTabButton()
}

class ContainerViewController: UIViewController {
    let topicListViewController = TopicListViewController(nibName: nil, bundle: nil)

    lazy var archiveListViewController: S1ArchiveListViewController = {
        return S1ArchiveListViewController(nibName: nil, bundle: nil)
    }()

    let topicListSelection: MutableProperty<S1TabBar.Selection> = MutableProperty(.none)

    let scrollTabBar = S1TabBar(frame: .zero)

    var selectedViewController: MutableProperty<UIViewController>
    var previouslySelectedViewController: UIViewController?

    private let pasteboardToast = PasteboardLinkHintToast()

    let pasteboardString = CurrentValueSubject<String, Never>("")
    let pasteboardContainsValidURL = CurrentValueSubject<Bool, Never>(false)

    let pasteboardAnimator = UIViewPropertyAnimator(duration: 0.3, timingParameters: UICubicTimingParameters(animationCurve: .easeInOut))

    var bag = Set<AnyCancellable>()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.selectedViewController = MutableProperty(self.topicListViewController)

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        topicListViewController.containerViewController = self
        scrollTabBar.tabbarDelegate = self

        // Bind ViewModel

        AppEnvironment.current.settings.forumOrder
            .map({ $0.first ?? [] })
            .removeDuplicates()
            .sink { [weak self] (keys) in
                guard let strongSelf = self else { return }
                strongSelf.scrollTabBar.keys = keys
                strongSelf.topicListViewController.reset()
            }
            .store(in: &bag)

        scrollTabBar.reactive.selection <~ MutableProperty
            .combineLatest(topicListSelection, selectedViewController)
            .map({ [weak self] (selection, selectedViewController) in
                guard let strongSelf = self else { return .none }
                if selectedViewController === strongSelf.topicListViewController {
                    return selection
                } else {
                    return .none
                }
            })

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification),
            name: .APPaletteDidChange,
            object: nil
        )

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

        view.addSubview(scrollTabBar)
        if #available(iOS 11.0, *) {
            scrollTabBar.snp.makeConstraints { (make) in
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                make.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-44.0)
            }
        } else {
            scrollTabBar.snp.makeConstraints { (make) in
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                make.height.equalTo(44.0)
            }
        }

        pasteboardToast.alpha = 0.0
        view.addSubview(pasteboardToast)

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
                            make.bottom.equalTo(strongSelf.scrollTabBar.snp.top).offset(-8.0)
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
                            make.top.equalTo(strongSelf.scrollTabBar.snp.top).offset(8.0)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }

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

        /// Suggested by https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/ImplementingaContainerViewController.html
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

// MARK: - S1TabBarDelegate

extension ContainerViewController: S1TabBarDelegate {
    func tabbar(_ tabbar: S1TabBar, didSelectedKey key: String) {
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
        scrollTabBar.updateColor()
        pasteboardToast.button.setTitleColor(AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint"), for: .normal)
        pasteboardToast.backgroundColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.bartint")
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
