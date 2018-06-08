//
//  TopicListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 4/9/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Ainoaibo
import ReactiveSwift
import ReactiveCocoa
import DeviceKit
import Crashlytics

class TopicListViewController: UIViewController {
    let viewModel: TopicListViewModel

    let naviItem = UINavigationItem()
    let navigationBar = UINavigationBar(frame: .zero)

    let tableView = UITableView(frame: .zero, style: .plain)

    lazy var refreshControl: ODRefreshControl = {
        return ODRefreshControl(in: tableView)
    }()

    let searchBar = UISearchBar(frame: .zero)
    let searchBarWrapperView = UIView(frame: .zero)
    let scrollTabBar = S1TabBar(frame: .zero)
    let footerView = LoadingFooterView()
    let refreshHUD = S1HUD(frame: .zero)

    // Model
    var cachedContentOffset = [String: CGPoint]()
    var cachedLastRefreshTime = [String: Date]()

    var loadingFlag = false
    var loadingMore = false
//    @property (nonatomic, strong) NSString *searchKeyword;

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        viewModel = TopicListViewModel(dataCenter: AppEnvironment.current.dataCenter)

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Navigation Bar
        naviItem.title = "Stage1st"
        naviItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "Settings"),
            style: .plain,
            target: self,
            action: #selector(settings)
        )
        naviItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "Archive"),
            style: .plain,
            target: self,
            action: #selector(archive)
        )

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

        // Tab Bar
        scrollTabBar.keys = self.keys()
        scrollTabBar.tabbarDelegate = self

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
        Crashlytics.sharedInstance().setObjectValue("TopicListViewController", forKey: "lastViewController")
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
            make.width.lessThanOrEqualTo(view.snp.width).offset(-10.0)
            make.height.lessThanOrEqualTo(view.snp.height).offset(-10.0)
        }
    }

    open override func didReceiveMemoryWarning() {
        viewModel.dataCenter.clearTopicListCache()
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

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewModel.traitCollection.value = traitCollection
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

extension TopicListViewController {
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

        viewModel.hudAction.signal.observeValues { [weak self] (action) in
            guard let strongSelf = self else { return }

            switch action {
            case .loading:
                strongSelf.refreshHUD.showActivityIndicator()
            case let .text(text):
                strongSelf.refreshHUD.showMessage(text)
            case .hide:
                strongSelf.refreshHUD.hide(withDelay: 0.0)
            }
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
    }
}

// MARK: - UITableViewDelegate

extension TopicListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let contentViewController = S1ContentViewController(viewModel: viewModel.contentViewModel(at: indexPath))
        navigationController?.pushViewController(contentViewController, animated: true)
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let notInLoading = !(loadingFlag || loadingMore)

        let target = viewModel.currentState.value.currentTarget

        guard target.isForum && notInLoading else {
            return
        }

        if indexPath.row == viewModel.topics.count - 15 {
            loadingMore = true
            tableView.tableFooterView = footerView
            S1LogDebug("Reach (almost) last topic, load more.")

            viewModel.fetchingMoreTriggered()

//            viewModel.loadNextPage { [weak self] (result) in
//                guard let strongSelf = self else { return }
//
//                // TODO: Show ReloadingFooterView if failed.
//                S1LogInfo("load next page \(result)")
//                tableView.tableFooterView = nil
//                tableView.reloadData()
//                strongSelf.loadingMore = false
//            }
        }
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
        fatalError()
//        objc_searchBarSearchButtonClicked(searchBar)
    }
}

// MARK: S1TabBarDelegate

extension TopicListViewController: S1TabBarDelegate {
    func tabbar(_ tabbar: S1TabBar!, didSelectedKey key: String!) {
        viewModel.tabBarTapped(key: key)
    }
}

// MARK: UINavigationBarDelegate

extension TopicListViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

//extension S1TopicListViewController {
//    @objc func presentInternalList(for type: S1InternalTopicListType) {
//        if isPresentingForumList(viewModel.currentKey) {
//            viewModel.cancelRequests()
//            cachedContentOffset[viewModel.currentKey] = tableView.contentOffset
//        }
//
//        viewModel.currentState.value = type == S1TopicListHistory ? .history : .favorite
//
//        tableView.reloadData()
//        viewModel.searchingTerm.value = searchBar.text ?? ""
//        tableView.setContentOffset(.zero, animated: false)
//        scrollTabBar.deselectAll()
//    }
//}

// MARK: - Actions
extension TopicListViewController {
    @objc func settings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let settingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsNavigation")
        self.present(settingsViewController, animated: true, completion: nil)
    }

    @objc func archive(_ sender: Any) {
        let viewController = S1ArchiveListViewController(nibName: nil, bundle: nil)
        navigationController?.pushViewController(viewController, animated: true)
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

        viewModel.pullToRefreshTriggered()
    }

    @objc func clearSearchBarText(_ gestureRecognizer: UISwipeGestureRecognizer) {
        searchBar.text = ""
        searchBar.delegate?.searchBar?(self.searchBar, textDidChange: "")
    }
}

// MARK: Notifications

extension TopicListViewController {
    @objc func updateTabbar() {
        viewModel.transitState(to: .loaded(.blank))
        scrollTabBar.keys = self.keys()
    }

    @objc func cloudKitStateChanged() {
        updateArchiveIcon()
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.background")

        tableView.separatorColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.separator")
        tableView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.background")
        tableView.indicatorStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .white : .default
        if let backgoundView = tableView.backgroundView {
            backgoundView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.background")
        }

        refreshControl.tintColor = AppEnvironment.current.colorManager.colorForKey("topiclist.refreshcontrol.tint")

        navigationBar.titleTextAttributes = [
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 17.0),
            NSAttributedStringKey.foregroundColor: AppEnvironment.current.colorManager.colorForKey("topiclist.navigationbar.titlelabel")
        ]

        searchBar.searchBarStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .minimal : .default
        searchBar.tintColor = AppEnvironment.current.colorManager.colorForKey("topiclist.searchbar.tint")
        searchBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("topiclist.searchbar.bartint")
        searchBar.keyboardAppearance = AppEnvironment.current.colorManager.isDarkTheme() ? .dark : .default
        if searchBar.isFirstResponder {
            searchBar.reloadInputViews()
        }

        footerView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.footer.background")
        footerView.label.textColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.footer.text")

        scrollTabBar.updateColor()

        navigationBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.bartint")
        navigationBar.tintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.tint")
        navigationBar.titleTextAttributes = [
            .foregroundColor: AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.title"),
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

    func keys() -> [String] {
        return AppEnvironment.current.settings.forumOrder.value.first ?? []
    }
}
