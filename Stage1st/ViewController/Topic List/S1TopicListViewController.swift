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

extension S1TopicListViewController {
    open override func viewDidLoad() {
        super.viewDidLoad()

        dataCenter = AppEnvironment.current.dataCenter
        viewModel = S1TopicListViewModel(dataCenter: dataCenter)

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(S1TopicListViewController.updateTabbar),
            name: .init(rawValue: "S1UserMayReorderedNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(S1TopicListViewController.didReceivePaletteChangeNotification),
            name: .APPaletteDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(S1TopicListViewController.cloudKitStateChanged),
            name: .YapDatabaseCloudKitStateChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(S1TopicListViewController.cloudKitStateChanged),
            name: .UIApplicationWillEnterForeground,
            object: nil
        )

        tableView.register(TopicListCell.self, forCellReuseIdentifier: "TopicListCell")
        tableView.register(TopicListHeaderView.self, forHeaderFooterViewReuseIdentifier: "TopicListHeaderView")

        bindViewModel()
    }

    open override func didReceiveMemoryWarning() {
        dataCenter.clearTopicListCache()
        S1Formatter.sharedInstance().clearCache()
    }

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
        return isPresentingDatabaseList(currentKey)
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

        guard !isPresentingDatabaseList(currentKey) else {
            return
        }

        guard !isPresentingSearchList(currentKey) else {
            return
        }

        guard notInLoading() else {
            return
        }

        if indexPath.row == viewModel.topics.count - 15 {
            loadingMore = true
            tableView.tableFooterView = footerView
            S1LogDebug("Reach (almost) last topic, load more.")

            viewModel.loadNextPageForKey(forumKeyMap[currentKey]!) { [weak self] (result) in
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
        if isPresentingDatabaseList(currentKey) {
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
        return isPresentingDatabaseList(currentKey) ? 20.0 : 0.0
    }
}

// MARK: UISearchBarDelegate

extension S1TopicListViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            viewModel.searchingTerm.value = searchText
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        objc_searchBarSearchButtonClicked(searchBar)
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
        if isPresentingForumList(currentKey) {
            viewModel.cancelRequests()
            cachedContentOffset[currentKey] = NSValue(cgPoint: tableView.contentOffset)
        }

        previousKey = currentKey
        currentKey = type == S1TopicListHistory ? "History" : "Favorite"

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
        navigationItem.rightBarButtonItems = []
        viewModel.cancelRequests()
        navigationItem.titleView = segControl
        if segControl.selectedSegmentIndex == 0 {
            presentInternalList(for: S1TopicListHistory)
        } else {
            presentInternalList(for: S1TopicListFavorite)
        }
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
        self.fetchTopics(forKey: self.currentKey, skipCache: true, scrollToTop: false)
    }

    @objc func segSelected(_ seg: UISegmentedControl) {
        switch seg.selectedSegmentIndex {
        case 0:
            self.presentInternalList(for: S1TopicListHistory)
        case 1:
            self.presentInternalList(for: S1TopicListFavorite)
        default:
            fatalError()
        }
    }

    @objc func clearSearchBarText(_ gestureRecognizer: UISwipeGestureRecognizer) {
        searchBar.text = ""
        searchBar.delegate?.searchBar?(self.searchBar, textDidChange: "")
    }
}
