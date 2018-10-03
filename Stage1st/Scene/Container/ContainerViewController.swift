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

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.selectedViewController = MutableProperty(self.topicListViewController)

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        topicListViewController.containerViewController = self
        scrollTabBar.tabbarDelegate = self

        // Bind ViewModel

        AppEnvironment.current.settings.forumOrder
            .map({ $0.first ?? [] })
            .skipRepeats()
            .producer.startWithValues { [weak self] (keys) in
                guard let strongSelf = self else { return }
                strongSelf.scrollTabBar.keys = keys
                strongSelf.topicListViewController.reset()
            }

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

        // Initialize Child View Controller

        applyChildViewControllerSwitch()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if Device().isOneOf([.iPhoneX, .simulator(.iPhoneX)]) {
            scrollTabBar.expectedButtonHeight = 49.0
        }

        view.addSubview(scrollTabBar)
        if #available(iOS 11.0, *) {
            scrollTabBar.snp.makeConstraints { (make) in
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                if Device().isOneOf([.iPhoneX, .simulator(.iPhoneX)]) {
                    make.top.equalTo(self.bottomLayoutGuide.snp.top).offset(-49.0)
                } else {
                    make.top.equalTo(self.bottomLayoutGuide.snp.top).offset(-44.0)
                }
            }
        } else {
            scrollTabBar.snp.makeConstraints { (make) in
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                make.height.equalTo(44.0)
            }
        }
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

extension ContainerViewController {
    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        scrollTabBar.updateColor()
    }
}
