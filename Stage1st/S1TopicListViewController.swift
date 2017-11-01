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

        view.addSubview(scrollTabBar)
        if #available(iOS 11.0, *) {
            scrollTabBar.snp.makeConstraints { (make) in
                make.top.equalTo(tableView.snp.bottom)
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
                make.top.equalTo(self.bottomLayoutGuide.snp.top).offset(-44.0)
            }
        } else {
            scrollTabBar.snp.makeConstraints { (make) in
                make.top.equalTo(tableView.snp.bottom)
                make.leading.trailing.equalTo(view)
                make.bottom.equalTo(view.snp.bottom)
            }
        }

        view.addSubview(refreshHUD)
        refreshHUD.snp.makeConstraints { (make) in
            make.center.equalTo(view)
            make.width.lessThanOrEqualTo(view)
            make.height.lessThanOrEqualTo(view)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.updateTabbar), name: .init(rawValue: "S1UserMayReorderedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.reloadTableData), name: .init(rawValue: "S1TopicUpdateNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.didReceivePaletteChangeNotification), name: .APPaletteDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.databaseConnectionDidUpdate), name: .UIDatabaseConnectionDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.cloudKitStateChanged), name: .YapDatabaseCloudKitStateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(S1TopicListViewController.cloudKitStateChanged), name: .UIApplicationWillEnterForeground, object: nil)

        tableView.register(TopicListCell.self, forCellReuseIdentifier: "TopicListCell")
        tableView.register(TopicListHeaderView.self, forHeaderFooterViewReuseIdentifier: "TopicListHeaderView")

        viewModel.cellTitleAttributes.producer.startWithValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.tableView.reloadData()
        }
    }

    open override func didReceiveMemoryWarning() {
        dataCenter.clearTopicListCache()
        S1Formatter.sharedInstance().clearCache()
    }
}

@objc
extension S1TopicListViewController {
    func isPresentingDatabaseList(_ key: String) -> Bool {
        switch S1TopicListViewModel.ContentState(key: key) {
        case .favorite, .history:
            return true
        default:
            return false
        }
    }

    func isPresentingSearchList(_ key: String) -> Bool {
        switch S1TopicListViewModel.ContentState(key: key) {
        case .search:
            return true
        default:
            return false
        }
    }

    func isPresentingForumList(_ key: String) -> Bool {
        switch S1TopicListViewModel.ContentState(key: key) {
        case .forum:
            return true
        default:
            return false
        }
    }

    func isPresentingBlankList(_ key: String) -> Bool {
        switch S1TopicListViewModel.ContentState(key: key) {
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
            DDLogDebug("[TopicListVC] Reach (almost) last topic, load more.")

            viewModel.loadNextPageForKey(forumKeyMap[currentKey]!) { [weak self] (result) in
                guard let strongSelf = self else { return }

                // TODO: Show ReloadingFooterView if failed.
                DDLogInfo("[TopicListVC] load next page \(result)")
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
        return isPresentingDatabaseList(currentKey) ? viewModel.numberOfSections() : 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isPresentingDatabaseList(currentKey) ? viewModel.numberOfItemsInSection(section) : viewModel.topics.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicListCell", for: indexPath) as! TopicListCell
        cell.configure(with: viewModel.cellViewModel(at: indexPath))
        return cell
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isPresentingDatabaseList(currentKey) {
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "TopicListHeaderView") as! TopicListHeaderView

            headerView.backgroundColor = ColorManager.shared.colorForKey("topiclist.tableview.header.background")
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
            cachedContentOffset![currentKey] = NSValue(cgPoint: tableView.contentOffset)
        }

        previousKey = currentKey
        currentKey = type == S1TopicListHistory ? "History" : "Favorite"
        if tableView.isHidden {
            tableView.isHidden = false
        }

        self.refreshControl.isHidden = true
        tableView.reloadData()
        viewModel.searchingTerm.value = searchBar.text ?? ""
        tableView.setContentOffset(.zero, animated: false)
        scrollTabBar.deselectAll()
    }
}
