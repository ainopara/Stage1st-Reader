//
//  TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Ainoaibo
import ReactiveSwift
import DeviceKit
import SwiftUI

final class TopicListViewController: UIViewController {

    let viewModel: TopicListViewModel

    let naviItem = UINavigationItem()
    let navigationBar = UINavigationBar(frame: .zero)

    let tableView = UITableView(frame: .zero, style: .plain)
    lazy var refreshControl: ODRefreshControl = { ODRefreshControl(in: tableView) }()
    let searchBar = UISearchBar(frame: .zero)
    let searchBarWrapperView = UIView(frame: .zero)
    let footerView = MessageFooterView()
    let refreshHUD = Hud(frame: .zero)
    let composeButton = UIButton()

    private var observations = [NSKeyValueObservation]()

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        viewModel = TopicListViewModel()

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Navigation Bar
        naviItem.title = "Stage1st"
        naviItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settings)
        )

        AppEnvironment.current.dataCenter.noticeCount
            .map { ($0?.myPost ?? 0) == 0 ? UIImage(systemName: "bell") : UIImage(systemName: "bell.fill") }
            .producer
            .start(on: UIScheduler())
            .observe(on: UIScheduler())
            .startWithValues { [weak self] (image) in
                guard let strongSelf = self else { return }
                strongSelf.naviItem.rightBarButtonItems = [
                    UIBarButtonItem(
                        image: UIImage(systemName: "archivebox"),
                        style: .plain,
                        target: strongSelf,
                        action: #selector(TopicListViewController.archive)
                    ),
                    UIBarButtonItem(
                        image: image,
                        style: .plain,
                        target: strongSelf,
                        action: #selector(TopicListViewController.notification)
                    )
                ]
            }

        navigationBar.delegate = self
        navigationBar.pushItem(naviItem, animated: false)

        // Search Bar
        searchBar.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 50.0)
        searchBar.delegate = self
        searchBar.backgroundImage = UIImage()
        let gestureRecognizer = UISwipeGestureRecognizer(
            target: self,
            action: #selector(clearSearchBarText)
        )
        gestureRecognizer.direction = [.left, .right]
        searchBar.addGestureRecognizer(gestureRecognizer)
        searchBar.accessibilityLabel = "Search Bar"

        // TableView
        tableView.rowHeight = 54.0
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.separatorInset = .zero
        tableView.delegate = self
        tableView.dataSource = self

        /// How wrapper view works: UISearchBar wrapped in a parent view with frame.y == 4.0 frame.height == 36
        /// The height of the parent view is 50 or 55 (in iPhone X)
        /// Adding the parent view to wrapper view with height == 44.0 makes searchBar looks vertical center.
        searchBarWrapperView.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 44.0)
        searchBarWrapperView.clipsToBounds = true
        searchBarWrapperView.addSubview(searchBar)
        searchBar.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalTo(searchBarWrapperView)
        }
        tableView.tableHeaderView = searchBarWrapperView

        composeButton.setTitle("发帖", for: .normal)
        composeButton.layer.cornerRadius = 25.0
        composeButton.clipsToBounds = true
        composeButton.setTitleColor(AppEnvironment.current.colorManager.colorForKey("topiclist.compose.title"), for: .normal)
        composeButton.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.compose.background")
        composeButton.isHidden = true

        tableView.register(
            TopicListCell.self,
            forCellReuseIdentifier: "TopicListCell"
        )

        tableView.register(
            TopicListHeaderView.self,
            forHeaderFooterViewReuseIdentifier: "TopicListHeaderView"
        )

        refreshControl.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification),
            name: .APPaletteDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitStateChanged),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        bindViewModel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        S1LogDebug("Dealloced")
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: -

extension TopicListViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        S1LogInfo("viewWillAppear")

        updateArchiveIcon()
        didReceivePaletteChangeNotification(nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        S1LogDebug("viewDidAppear")
        AppEnvironment.current.eventTracker.setObjectValue("TopicListViewController", forKey: "lastViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(navigationBar)
        navigationBar.snp.makeConstraints({ (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalTo(self.view)
        })

        view.addSubview(tableView)
        tableView.snp.makeConstraints({ (make) in
            make.leading.trailing.equalTo(view)
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(view.snp.bottom)
        })

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { (make) in
            make.center.equalTo(view)
            make.width.lessThanOrEqualTo(view.snp.width).offset(-10.0)
            make.height.lessThanOrEqualTo(view.snp.height).offset(-10.0)
        }

        view.addSubview(composeButton)
        composeButton.snp.makeConstraints { (make) in
            make.right.bottom.equalTo(view).inset(10.0)
            make.width.height.equalTo(50.0)
        }

        viewModel.traitCollection.value = self.traitCollection
    }

    override func didReceiveMemoryWarning() {
        viewModel.dataCenter.clearTopicListCache()
        S1Formatter.sharedInstance().clearCache()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if
            searchBar.subviews.count > 0,
            searchBar.subviews[0].subviews.count > 1,
            searchBar.subviews[0].subviews[1].isKind(of: NSClassFromString("UISearchBarTextField")!)
        {
            let textFieldFrame = searchBar.subviews[0].subviews[1].frame
            let wrapperHeight = 2 * textFieldFrame.origin.y + textFieldFrame.height
            if self.searchBarWrapperView.frame.height != wrapperHeight && wrapperHeight != 0 {
                self.searchBarWrapperView.frame = mutate(self.searchBarWrapperView.frame) { (value: inout CGRect) in
                    value.size.height = wrapperHeight
                }
                self.tableView.tableHeaderView = self.searchBarWrapperView
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if UIDevice.current.userInterfaceIdiom == .phone && AppEnvironment.current.settings.forcePortraitForPhone.value {
            return
        }

        S1LogDebug("View Will Change To Size: h\(size.height), w\(size.width)")
        self.view.frame = mutate(self.view.frame, change: { (value: inout CGRect) in
            value.size = size
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewModel.traitCollection.value = traitCollection
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

extension TopicListViewController {
    func bindViewModel() {

        /// viewModel.tableViewOffset <~ tableView.contentOffset
        let tableViewContentOffsetToken = tableView.observe(\.contentOffset, options: [.new]) { [weak self] (tableView, change) in
            guard let strongSelf = self else { return }
            guard let offset = change.newValue else { return }

            S1LogVerbose("Offset: \(offset)")

            if strongSelf.viewModel.tableViewOffset.value != offset {
                strongSelf.viewModel.tableViewOffset.value = offset
            }
        }

        observations.append(tableViewContentOffsetToken)

        /// viewModel.tableViewOffsetAction ~> tableView.contentOffset
        viewModel.tableViewOffsetAction.observeValues { [weak self] (action) in
            guard let strongSelf = self else { return }

            S1LogDebug("TableView Offset Action: \(action)")

            switch action {
            case .restore(let offset):
                /// A dirty hack to make content offset restoration as precise as possible. Work for iOS 11.
                strongSelf.tableView.layoutIfNeeded()
                strongSelf.tableView.setContentOffset(offset, animated: true)
                strongSelf.tableView.layoutIfNeeded()
                strongSelf.tableView.setContentOffset(offset, animated: false)

                DispatchQueue.main.async {
                    strongSelf.tableView.setContentOffset(offset, animated: false)
                }

            case .toTop:
                guard strongSelf.tableView.numberOfRows(inSection: 0) > 0 else { return }

                strongSelf.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: false)

                /// Force scroll to first cell when finish loading. in case cocoa didn't do that for you.
                if strongSelf.tableView.contentOffset.y < 0.0 {
                    if strongSelf.tableView.isTracking {
                        strongSelf.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .none, animated: true)
                    } else {
                        strongSelf.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: true)
                    }
                }
            }
        }

        /// viewModel.tableViewReloading ~> tableView.relaodData()
        viewModel.tableViewReloading.observeValues { [weak self] in
            guard let strongSelf = self else { return }

            S1LogInfo("Reloading tableView")
            strongSelf.tableView.reloadData()
        }

        /// viewModel.tableViewCellUpdate ~> tableView.update()
        viewModel.tableViewCellUpdate.observeValues { [weak self] (updatedModelIndexPaths) in
            guard let strongSelf = self else { return }

            strongSelf.tableView.beginUpdates()
            strongSelf.tableView.reloadRows(at: updatedModelIndexPaths, with: UITableView.RowAnimation.automatic)
            strongSelf.tableView.endUpdates()
        }

        /// viewModel.hudAction ~> refresHUD.actions()
        viewModel.hudAction.signal.observeValues { [weak self] (action) in
            guard let strongSelf = self else { return }

            switch action {
            case .loading:
                strongSelf.refreshHUD.showLoadingIndicator()
            case let .text(text):
                strongSelf.refreshHUD.show(message: text)
            case let .hide(delay):
                strongSelf.refreshHUD.hide(delay: delay)
            }
        }

        /// viewModel.searchBarPlaceholderText ~> searchBar.placeholder
        viewModel.searchBarPlaceholderText.producer.startWithValues { [weak self] (placeholderText) in
            guard let strongSelf = self else { return }
            strongSelf.searchBar.placeholder = placeholderText
        }

        tableView.reactive.isHidden <~ viewModel.isTableViewHidden
        refreshControl.reactive.isHidden <~ viewModel.isRefreshControlHidden

        viewModel.refreshControlEndRefreshing.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            if strongSelf.refreshControl.refreshing {
                strongSelf.refreshControl.endRefreshing()
            }
        }

        viewModel.searchTextClearAction.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.searchBar.text = ""
            strongSelf.searchBar.delegate?.searchBar?(strongSelf.searchBar, textDidChange: "")
        }

        viewModel.isShowingFooterView.signal.observeValues { [weak self] (showing) in
            guard let strongSelf = self else { return }
            if showing && strongSelf.tableView.tableFooterView == nil {
                strongSelf.tableView.tableFooterView = strongSelf.footerView
            } else if !showing && strongSelf.tableView.tableFooterView === strongSelf.footerView {
                strongSelf.tableView.tableFooterView = nil
            }
        }

        footerView.message <~ viewModel.footerViewMessage

        let refreshControlRefreshingToken = refreshControl.observe(\.refreshing, options: [.new]) { [weak self] (refreshControl, change) in
            guard let strongSelf = self else { return }
            guard let isRefreshing = change.newValue else { return }

            if strongSelf.viewModel.refreshControlIsRefreshing.value != isRefreshing {
                strongSelf.viewModel.refreshControlIsRefreshing.value = isRefreshing
            }
        }

        observations.append(refreshControlRefreshingToken)

        composeButton.reactive.controlEvents(.touchUpInside).signal.observeValues { [weak self] (button) in
            guard let strongSelf = self else { return }
            guard case let .forum(forum) = strongSelf.viewModel.model.value.target else { return }
            let composeViewController = TopicComposeViewController(forumID: forum.key)
            strongSelf.present(UINavigationController(rootViewController: composeViewController), animated: true, completion: nil)
        }
    }
}

// MARK: - UITableViewDelegate

extension TopicListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let contentViewController = ContentViewController(viewModel: viewModel.contentViewModel(at: indexPath))
        navigationController?.pushViewController(contentViewController, animated: true)
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // TODO: Make this friendly for UI Snapshot tests
        self.viewModel.willDisplayCell(at: indexPath)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0.0 && searchBar.isFirstResponder {
            searchBar.resignFirstResponder()
        }
    }
}

// MARK: UITableViewDataSource

extension TopicListViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(in: section)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicListCell", for: indexPath) as! TopicListCell
        cell.configure(with: viewModel.cellViewModel(at: indexPath))
        return cell
    }
}

// MARK: UISearchBarDelegate

extension TopicListViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.searchingTerm.value = searchText
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchBar.isFirstResponder {
            searchBar.resignFirstResponder()
        }

        guard let term = searchBar.text, term.count > 0 else {
            return
        }

        viewModel.searchButtonTapped(term: term)
    }
}

// MARK: UINavigationBarDelegate

extension TopicListViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: - Actions

extension TopicListViewController {

    @objc func settings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let settingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsNavigation")
        self.present(settingsViewController, animated: true, completion: nil)
    }

    @objc func archive(_ sender: Any) {
//        let state = SettingsViewState(
//            currentUsernameSubject: AppEnvironment.current.settings.currentUsername,
//            showLoginViewController: { [weak self] in
//                guard let self = self else { return }
//                self.present(LoginViewController(), animated: true, completion: nil)
//            }
//        )
//        let settingsViewController = UIHostingController(rootView: SettingsView(state: state))
//        self.present(settingsViewController, animated: true, completion: nil)
        // TODO: 
        self.viewModel.containerShouldSwitchToArchiveList.send(())
    }

    @objc func notification(_ sender: Any) {
        AppEnvironment.current.dataCenter.noticeCount.value = nil
        self.navigationController?.pushViewController(NoticeViewController(viewModel: NoticeViewModel()), animated: true)
    }

    @objc func refresh(_ sender: Any) {
        guard !refreshControl.isHidden else {
            refreshControl.endRefreshing()
            return
        }

        UISelectionFeedbackGenerator().selectionChanged()
        viewModel.pullToRefreshTriggered()
    }

    @objc func clearSearchBarText(_ gestureRecognizer: UISwipeGestureRecognizer) {
        searchBar.text = ""
        searchBar.delegate?.searchBar?(self.searchBar, textDidChange: "")
    }

    func reset() {
        viewModel.reset()
    }

    func switchToPresenting(key: Int) {
        if AppEnvironment.current.settings.tapticFeedbackForForumSwitch.value {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        viewModel.tabBarTapped(key: key)
    }

    func switchToPresentingKeyIfChanged(key: Int) {
        if AppEnvironment.current.settings.tapticFeedbackForForumSwitch.value {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        if case let .forum(forum) = self.viewModel.model.value.target, forum.key == key {
            /// We already presenting this key, nothing to do.
        } else {
            viewModel.reset()
            viewModel.tabBarTapped(key: key)
        }
    }
}

// MARK: Notifications

extension TopicListViewController {

    @objc func cloudKitStateChanged() {
        updateArchiveIcon()
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        let colorManager = AppEnvironment.current.colorManager
        view.backgroundColor = colorManager.colorForKey("topiclist.background")

        tableView.separatorColor = colorManager.colorForKey("topiclist.tableview.separator")
        tableView.backgroundColor = colorManager.colorForKey("topiclist.tableview.background")
        tableView.indicatorStyle = colorManager.isDarkTheme() ? .white : .default
        if let backgoundView = tableView.backgroundView {
            backgoundView.backgroundColor = colorManager.colorForKey("topiclist.tableview.background")
        }

        refreshControl.tintColor = colorManager.colorForKey("topiclist.refreshcontrol.tint")

        searchBar.searchBarStyle = colorManager.isDarkTheme() ? .minimal : .default
        searchBar.tintColor = colorManager.colorForKey("topiclist.searchbar.tint")
        searchBar.barTintColor = colorManager.colorForKey("topiclist.searchbar.bartint")
        searchBar.keyboardAppearance = colorManager.isDarkTheme() ? .dark : .default
        if searchBar.isFirstResponder {
            searchBar.reloadInputViews()
        }

        footerView.backgroundColor = colorManager.colorForKey("topiclist.tableview.footer.background")
        footerView.textColor.value = colorManager.colorForKey("topiclist.tableview.footer.text")

        navigationBar.barTintColor = colorManager.colorForKey("appearance.navigationbar.bartint")
        navigationBar.tintColor = colorManager.colorForKey("appearance.navigationbar.tint")
        navigationBar.titleTextAttributes = [
            .foregroundColor: colorManager.colorForKey("appearance.navigationbar.title"),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ]

        setNeedsStatusBarAppearanceUpdate()
    }
}

// MARK: - Helpers

extension TopicListViewController {
    func updateArchiveIcon() {
        // Archive animation as sync indicator is not implemented in this version.
    }
}
