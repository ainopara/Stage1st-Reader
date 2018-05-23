//
//  TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack
import ReactiveSwift
import ReactiveCocoa
import DeviceKit
import Crashlytics

class S1TopicListViewController: UIViewController {
    let viewModel: S1TopicListViewModel

    let naviItem = UINavigationItem()
    let navigationBar = UINavigationBar(frame: .zero)
    let titleLabel = UILabel(frame: .zero)
    let segControl = UISegmentedControl(items: [
        NSLocalizedString("TopicListViewController.SegmentControl_History", comment: "History"),
        NSLocalizedString("TopicListViewController.SegmentControl_Favorite", comment: "Favorite")
    ])

    lazy var settingsItem: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage.init(named: "Settings"),
            style: .plain,
            target: self,
            action: #selector(settings)
        )
    }()

    let archiveButton = AnimationButton(
        frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0),
        image: UIImage(named: "Archive")!
    )

    lazy var historyItem: UIBarButtonItem = {
        let item = UIBarButtonItem(customView: archiveButton)
        item.accessibilityLabel = "Archive Button"
        return item
    }()

    let tableView = UITableView(frame: .zero, style: .plain)

    lazy var refreshControl: ODRefreshControl = {
        return ODRefreshControl(in: tableView)
    }()

    let searchBar = UISearchBar(frame: .zero)
    let searchBarWrapperView = UIView(frame: .zero)
    let scrollTabBar = S1TabBar(frame: .zero)
    let footerView = LoadingFooterView()
    let refreshHUD = S1HUD(frame: .zero)

    var dataCenter: DataCenter {
        return viewModel.dataCenter
    }

    var keyValueObservations = [NSKeyValueObservation]()

    // Model
    var cachedContentOffset = [String: CGPoint]()
    var cachedLastRefreshTime = [String: Date]()
    lazy var forumKeyMap: [String: String] = {
        let path = Bundle.main.path(forResource: "ForumKeyMap", ofType: "plist")!
        let map = NSDictionary(contentsOfFile: path)!
        return map as! [String: String]
    }()

    var loadingFlag = false
    var loadingMore = false
//    @property (nonatomic, strong) NSString *searchKeyword;

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        viewModel = S1TopicListViewModel(dataCenter: AppEnvironment.current.dataCenter)

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Navigation Bar
        titleLabel.text = "Stage1st"
        titleLabel.font = UIFont.systemFont(ofSize: 17.0)
        titleLabel.sizeToFit()

        segControl.setWidth(80.0, forSegmentAt: 0)
        segControl.setWidth(80.0, forSegmentAt: 1)
        segControl.selectedSegmentIndex = 0

        naviItem.titleView = titleLabel
        naviItem.leftBarButtonItem = settingsItem
        naviItem.rightBarButtonItem = historyItem

        navigationBar.delegate = self
        navigationBar.pushItem(naviItem, animated: false)

        // Search Bar
        if #available(iOS 11.0, *) {
            searchBar.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 50.0)
        } else {
            searchBar.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 40.0)
        }
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

        if #available(iOS 11.0, *) {
            searchBarWrapperView.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 44.0)
            searchBarWrapperView.clipsToBounds = true
            searchBarWrapperView.addSubview(searchBar)
            searchBar.snp.makeConstraints { (make) in
                make.leading.trailing.top.equalTo(searchBarWrapperView)
                make.bottom.equalTo(searchBarWrapperView.snp.bottom).offset(6.0)
            }
            tableView.tableHeaderView = searchBarWrapperView
        } else {
            tableView.tableHeaderView = searchBar
        }

        tableView.register(
            TopicListCell.self,
            forCellReuseIdentifier: "TopicListCell"
        )

        tableView.register(
            TopicListHeaderView.self,
            forHeaderFooterViewReuseIdentifier: "TopicListHeaderView"
        )

        let tableViewContentOffsetObservation = tableView.observe(\.contentOffset, options: [.new]) { [weak self] (tableView, change) in
            guard let strongSelf = self else { return }
            guard let newOffset = change.newValue else { return }
            guard strongSelf.viewModel.currentState.value.isArchive else { return }
            guard newOffset.y < -10.0 && !strongSelf.searchBar.isFirstResponder  else { return }

            strongSelf.searchBar.becomeFirstResponder()
        }

        keyValueObservations.append(tableViewContentOffsetObservation)

        // Tab Bar
        scrollTabBar.keys = self.keys()
        scrollTabBar.tabbarDelegate = self

        archiveButton.addTarget(
            self,
            action: #selector(archive),
            for: .touchUpInside
        )

        segControl.addTarget(
            self,
            action: #selector(segSelected),
            for: .valueChanged
        )

        refreshControl.addTarget(
            self,
            action: #selector(refresh),
            for: .valueChanged
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTabbar),
            name: .init(rawValue: "S1UserMayReorderedNotification"),
            object: nil
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
            name: .UIApplicationWillEnterForeground,
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

extension S1TopicListViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        S1LogInfo("viewWillAppear")

        updateArchiveIcon()
        didReceivePaletteChangeNotification(nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        S1LogDebug("viewDidAppear")
        Crashlytics().setObjectValue("TopicListViewController", forKey: "lastViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(navigationBar)
        if #available(iOS 11.0, *) {
            navigationBar.snp.makeConstraints({ (make) in
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
                make.leading.trailing.equalTo(self.view)
            })
        } else {
            navigationBar.snp.makeConstraints({ (make) in
                make.top.equalTo(view.snp.top)
                make.leading.trailing.equalTo(self.view)
                make.bottom.equalTo(self.topLayoutGuide.snp.bottom).offset(44.0)
            })
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints({ (make) in
            make.leading.trailing.equalTo(view)
            make.top.equalTo(navigationBar.snp.bottom)
        })

        if Device().isOneOf([.iPhoneX, .simulator(.iPhoneX)]) {
            scrollTabBar.expectedButtonHeight = 49.0
        }

        view.addSubview(scrollTabBar)
        if #available(iOS 11.0, *) {
            scrollTabBar.snp.makeConstraints { (make) in
                make.top.equalTo(tableView.snp.bottom)
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
                make.top.equalTo(tableView.snp.bottom)
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                make.height.equalTo(44.0)
            }
        }

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { (make) in
            make.center.equalTo(view)
            make.width.lessThanOrEqualTo(view)
            make.height.lessThanOrEqualTo(view)
        }
    }

    open override func didReceiveMemoryWarning() {
        dataCenter.clearTopicListCache()
        S1Formatter.sharedInstance().clearCache()
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
}

extension S1TopicListViewController {
    func bindViewModel() {
        viewModel.tableViewReloading.observeValues { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.tableView.reloadData()
        }

        viewModel.tableViewCellUpdate.observeValues { [weak self] (updatedModelIndexPaths) in
            guard let strongSelf = self else { return }

            strongSelf.tableView.beginUpdates()
            strongSelf.tableView.reloadRows(at: updatedModelIndexPaths, with: UITableViewRowAnimation.automatic)
            strongSelf.tableView.endUpdates()
        }

        viewModel.searchBarPlaceholderText.producer.startWithValues { [weak self] (placeholderText) in
            guard let strongSelf = self else { return }
            strongSelf.searchBar.placeholder = placeholderText
        }

        tableView.reactive.isHidden <~ viewModel.isTableViewHidden

        viewModel.isRefreshControlHidden.producer.startWithValues { [weak self] (hidden) in
            guard let strongSelf = self else { return }
            strongSelf.refreshControl.isHidden = hidden
        }

        viewModel.isShowingSegmentControl.producer.startWithValues { [weak self] (isShowingSegmentControl) in
            guard let strongSelf = self else { return }
            if isShowingSegmentControl {
                strongSelf.naviItem.titleView = strongSelf.segControl
            } else {
                strongSelf.naviItem.titleView = strongSelf.titleLabel
            }
        }

        viewModel.isShowingArchiveButton.producer.startWithValues { [weak self] (isShowingArchiveButton) in
            guard let strongSelf = self else { return }
            if isShowingArchiveButton {
                strongSelf.naviItem.rightBarButtonItems = [strongSelf.historyItem]
            } else {
                strongSelf.naviItem.rightBarButtonItems = []
            }
        }
    }
}

@objc
extension S1TopicListViewController {
    func isPresentingDatabaseList(_ key: String) -> Bool {
        switch S1TopicListViewModel.State(key: key) {
        case .favorite, .history:
            return true
        default:
            return false
        }
    }

    func isPresentingSearchList(_ key: String) -> Bool {
        switch S1TopicListViewModel.State(key: key) {
        case .search:
            return true
        default:
            return false
        }
    }

    func isPresentingForumList(_ key: String) -> Bool {
        switch S1TopicListViewModel.State(key: key) {
        case .forum:
            return true
        default:
            return false
        }
    }

    func isPresentingBlankList(_ key: String) -> Bool {
        switch S1TopicListViewModel.State(key: key) {
        case .blank:
            return true
        default:
            return false
        }
    }
}

// MARK: Style

extension S1TopicListViewController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return ColorManager.shared.isDarkTheme() ? .lightContent : .default
    }
}

// MARK: - UITableViewDelegate

extension S1TopicListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let contentViewController = S1ContentViewController(viewModel: viewModel.contentViewModel(at: indexPath))
        self.navigationController?.pushViewController(contentViewController, animated: true)
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch viewModel.currentState.value {
        case .history, .favorite:
            return true
        default:
            return false
        }
    }

    public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if viewModel.currentState.value == .history {
            let deleteAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("TopicListViewController.TableView.CellAction.Delete", comment: ""), handler: { [weak self] (_, indexPath) in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.deleteTopicAtIndexPath(indexPath)
            })
            deleteAction.backgroundColor = ColorManager.shared.colorForKey("topiclist.cell.action.delete")

            return [deleteAction]
        }

        if viewModel.currentState.value == .favorite {
            let cancelFavoriteAction = UITableViewRowAction(style: .normal, title: NSLocalizedString("TopicListViewController.TableView.CellAction.CancelFavorite", comment: ""), handler: { [weak self] (_, indexPath) in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.unfavoriteTopicAtIndexPath(indexPath)
            })
            cancelFavoriteAction.backgroundColor = ColorManager.shared.colorForKey("topiclist.cell.action.cancelfavorite")
            return [cancelFavoriteAction]
        }

        assert(false, "this should never happen!")
        return nil
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        func notInLoading() -> Bool {
            return !(loadingFlag || loadingMore)
        }

        guard !isPresentingDatabaseList(viewModel.currentKey) else {
            return
        }

        guard !isPresentingSearchList(viewModel.currentKey) else {
            return
        }

        guard notInLoading() else {
            return
        }

        if indexPath.row == viewModel.topics.count - 15 {
            loadingMore = true
            tableView.tableFooterView = footerView
            S1LogDebug("Reach (almost) last topic, load more.")

            viewModel.loadNextPageForKey(forumKeyMap[viewModel.currentKey]!) { [weak self] (result) in
                guard let strongSelf = self else { return }

                // TODO: Show ReloadingFooterView if failed.
                S1LogInfo("load next page \(result)")
                tableView.tableFooterView = nil
                tableView.reloadData()
                strongSelf.loadingMore = false
            }
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0.0 {
            searchBar.resignFirstResponder()
        }
    }
}

// MARK: UITableViewDataSource

extension S1TopicListViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        switch viewModel.currentState.value {
        case .favorite, .history:
            return viewModel.numberOfSections()
        case .blank:
            return 0
        case .forum(key: _), .search:
            return 1
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.currentState.value {
        case .favorite, .history:
            return viewModel.numberOfItemsInSection(section)
        case .blank:
            return 0
        case .forum(key: _), .search:
            return viewModel.topics.count
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicListCell", for: indexPath) as! TopicListCell
        cell.configure(with: viewModel.cellViewModel(at: indexPath))
        return cell
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isPresentingDatabaseList(viewModel.currentKey) {
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "TopicListHeaderView") as! TopicListHeaderView

            headerView.backgroundView?.backgroundColor = ColorManager.shared.colorForKey("topiclist.tableview.header.background")
            headerView.label.textColor = ColorManager.shared.colorForKey("topiclist.tableview.header.text")
            headerView.label.text = viewModel.viewMappings?.group(forSection: UInt(section)) ?? "Unknown"

            return headerView
        } else {
            return nil
        }
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.currentState.value {
        case .history, .favorite:
            return 20.0
        default:
            return 0.0
        }
    }
}

// MARK: UISearchBarDelegate

extension S1TopicListViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            viewModel.searchingTerm.value = searchText
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        fatalError()
//        objc_searchBarSearchButtonClicked(searchBar)
    }
}

// MARK: S1TabBarDelegate

extension S1TopicListViewController: S1TabBarDelegate {
    func tabbar(_ tabbar: S1TabBar!, didSelectedKey key: String!) {
        viewModel.tabbarTapped(key: key)
    }
}

// MARK: UINavigationBarDelegate

extension S1TopicListViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: -

extension S1TopicListViewController {
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewModel.traitCollection.value = traitCollection
    }
}

extension S1TopicListViewController {
    @objc func presentInternalList(for type: S1InternalTopicListType) {
        if isPresentingForumList(viewModel.currentKey) {
            viewModel.cancelRequests()
            cachedContentOffset[viewModel.currentKey] = tableView.contentOffset
        }

        viewModel.currentState.value = type == S1TopicListHistory ? .history : .favorite

        tableView.reloadData()
        viewModel.searchingTerm.value = searchBar.text ?? ""
        tableView.setContentOffset(.zero, animated: false)
        scrollTabBar.deselectAll()
    }
}

// MARK: - Actions
extension S1TopicListViewController {
    @objc func settings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let settingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsNavigation")
        self.present(settingsViewController, animated: true, completion: nil)
    }

    @objc func archive(_ sender: Any) {
        let viewController = S1ArchiveListViewController(nibName: nil, bundle: nil)
        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc func segSelected(_ seg: UISegmentedControl) {
        viewModel.segmentControlIndexChanged(newValue: seg.selectedSegmentIndex)
    }

    @objc func refresh(_ sender: Any) {
        guard !refreshControl.isHidden else {
            refreshControl.endRefreshing()
            return
        }

        guard scrollTabBar.enabled else {
            refreshControl.endRefreshing()
            return
        }

        // fetch topics for current key
        fatalError()
//        self.fetchTopics(forKey: self.currentKey, skipCache: true, scrollToTop: false)
    }

    @objc func clearSearchBarText(_ gestureRecognizer: UISwipeGestureRecognizer) {
        searchBar.text = ""
        searchBar.delegate?.searchBar?(self.searchBar, textDidChange: "")
    }
}

extension S1TopicListViewController {
    func updateArchiveIcon() {

    }

    func keys() -> [String] {
        guard
            let arrays = UserDefaults.standard.array(forKey: "Order") as? [[String]],
            let keys = arrays.first
        else {
            return []
        }

        return keys
    }
}

extension S1TopicListViewController {
    @objc func updateTabbar() {
        fatalError()
    }

    @objc func cloudKitStateChanged() {
        updateArchiveIcon()
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = ColorManager.shared.colorForKey("topiclist.background")

        tableView.separatorColor = ColorManager.shared.colorForKey("topiclist.tableview.separator")
        tableView.backgroundColor = ColorManager.shared.colorForKey("topiclist.tableview.background")
        tableView.indicatorStyle = ColorManager.shared.isDarkTheme() ? .white : .default
        if let backgoundView = tableView.backgroundView {
            backgoundView.backgroundColor = ColorManager.shared.colorForKey("topiclist.tableview.background")
        }

        refreshControl.tintColor = ColorManager.shared.colorForKey("topiclist.refreshcontrol.tint")

        titleLabel.textColor = ColorManager.shared.colorForKey("topiclist.navigationbar.titlelabel")

        searchBar.searchBarStyle = ColorManager.shared.isDarkTheme() ? .minimal : .default
        searchBar.tintColor = ColorManager.shared.colorForKey("topiclist.searchbar.tint")
        searchBar.barTintColor = ColorManager.shared.colorForKey("topiclist.searchbar.bartint")
        searchBar.keyboardAppearance = ColorManager.shared.isDarkTheme() ? .dark : .default
        if searchBar.isFirstResponder {
            searchBar.reloadInputViews()
        }

        footerView.backgroundColor = ColorManager.shared.colorForKey("topiclist.tableview.footer.background")
        footerView.label.textColor = ColorManager.shared.colorForKey("topiclist.tableview.footer.text")

        scrollTabBar.updateColor()

        navigationBar.barTintColor = ColorManager.shared.colorForKey("appearance.navigationbar.bartint")
        navigationBar.tintColor = ColorManager.shared.colorForKey("appearance.navigationbar.tint")
        navigationBar.titleTextAttributes = [
            .foregroundColor: ColorManager.shared.colorForKey("appearance.navigationbar.title"),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ]

        archiveButton.tintColor = ColorManager.shared.colorForKey("topiclist.navigationbar.titlelabel")

        setNeedsStatusBarAppearanceUpdate()
    }
}
