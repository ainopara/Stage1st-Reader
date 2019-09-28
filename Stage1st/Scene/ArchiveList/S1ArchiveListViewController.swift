//
//  S1ArchiveListViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/5/23.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import DeviceKit
import Ainoaibo
import ReactiveSwift

class S1ArchiveListViewController: UIViewController {

    let viewModel: S1ArchiveListViewModel

    let naviItem = UINavigationItem()
    let navigationBar = UINavigationBar(frame: .zero)
    let segControl = UISegmentedControl(items: [
        NSLocalizedString("TopicListViewController.SegmentControl_History", comment: "History"),
        NSLocalizedString("TopicListViewController.SegmentControl_Favorite", comment: "Favorite")
    ])

    let tableView = UITableView(frame: .zero, style: .plain)

    let searchBar = UISearchBar(frame: .zero)
    let searchBarWrapperView = UIView(frame: .zero)

    var dataCenter: DataCenter {
        return viewModel.dataCenter
    }

    var keyValueObservations = [NSKeyValueObservation]()

    var blockingEarlyNoise = true

    // MARK: -

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        viewModel = S1ArchiveListViewModel()

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // Navigation Bar

        segControl.setWidth(80.0, forSegmentAt: 0)
        segControl.setWidth(80.0, forSegmentAt: 1)
        segControl.selectedSegmentIndex = 0

        naviItem.titleView = segControl
        naviItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "Settings"),
            style: .plain,
            target: self,
            action: #selector(settings)
        )

        AppEnvironment.current.dataCenter.noticeCount
            .map { ($0?.myPost ?? 0) == 0 ? UIImage(named: "Notice") : UIImage(named: "Notice2") }
            .producer
            .start(on: UIScheduler())
            .observe(on: UIScheduler())
            .startWithValues { [weak self] (image) in
                guard let strongSelf = self else { return }
                strongSelf.naviItem.rightBarButtonItem = UIBarButtonItem(
                    image: image,
                    style: .plain,
                    target: strongSelf,
                    action: #selector(S1ArchiveListViewController.notification)
                )
        }

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
            guard newOffset.y < -10.0 && !strongSelf.searchBar.isFirstResponder  else { return }
            guard !strongSelf.blockingEarlyNoise else { return }

            strongSelf.searchBar.becomeFirstResponder()
        }

        keyValueObservations.append(tableViewContentOffsetObservation)

        segControl.addTarget(
            self,
            action: #selector(segSelected),
            for: .valueChanged
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceivePaletteChangeNotification),
            name: .APPaletteDidChange,
            object: nil
        )

        bindViewModel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        didReceivePaletteChangeNotification(nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        AppEnvironment.current.eventTracker.setObjectValue("ArchiveListViewController", forKey: "lastViewController")
        blockingEarlyNoise = false
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
            make.bottom.equalTo(view.snp.bottom)
        })

        viewModel.traitCollection.value = self.traitCollection
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if #available(iOS 11.0, *) {
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
    }

    func bindViewModel() {
        viewModel.tableViewReloading.observeValues { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.tableView.reloadData()
        }

        viewModel.tableViewCellUpdate.observeValues { [weak self] (updatedModelIndexPaths) in
            guard let strongSelf = self else { return }

            strongSelf.tableView.beginUpdates()
            strongSelf.tableView.reloadRows(at: updatedModelIndexPaths, with: UITableView.RowAnimation.automatic)
            strongSelf.tableView.endUpdates()
        }

        viewModel.searchBarPlaceholderText.producer.startWithValues { [weak self] (placeholderText) in
            guard let strongSelf = self else { return }
            strongSelf.searchBar.placeholder = placeholderText
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        viewModel.traitCollection.value = self.traitCollection
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

extension S1ArchiveListViewController {
    @objc func settings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let settingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsNavigation")
        self.present(settingsViewController, animated: true, completion: nil)
    }

    @objc func notification(_ sender: Any) {
        self.navigationController?.pushViewController(NoticeViewController(viewModel: NoticeViewModel()), animated: true)
    }
}

// MARK: - UITableViewDataSource

extension S1ArchiveListViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItemsInSection(section)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicListCell", for: indexPath) as! TopicListCell
        cell.configure(with: viewModel.cellViewModel(at: indexPath))
        return cell
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "TopicListHeaderView") as! TopicListHeaderView

        headerView.backgroundView?.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.header.background")
        headerView.label.textColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.header.text")
        headerView.label.text = viewModel.viewMappings?.group(forSection: UInt(section)) ?? "Unknown"

        return headerView
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20.0
    }
}

// MARK: UITableViewDelegate

extension S1ArchiveListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let contentViewController = ContentViewController(viewModel: viewModel.contentViewModel(at: indexPath))
        self.navigationController?.pushViewController(contentViewController, animated: true)
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if viewModel.currentState.value == .history {
            let deleteAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("TopicListViewController.TableView.CellAction.Delete", comment: ""), handler: { [weak self] (_, indexPath) in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.deleteTopicAtIndexPath(indexPath)
            })
            deleteAction.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.cell.action.delete")

            return [deleteAction]
        }

        if viewModel.currentState.value == .favorite {
            let cancelFavoriteAction = UITableViewRowAction(style: .normal, title: NSLocalizedString("TopicListViewController.TableView.CellAction.CancelFavorite", comment: ""), handler: { [weak self] (_, indexPath) in
                guard let strongSelf = self else { return }
                strongSelf.viewModel.unfavoriteTopicAtIndexPath(indexPath)
            })
            cancelFavoriteAction.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.cell.action.cancelfavorite")
            return [cancelFavoriteAction]
        }

        assert(false, "this should never happen!")
        return nil
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0.0 && searchBar.isFirstResponder {
            searchBar.resignFirstResponder()
        }
    }
}

// MARK: UINavigationBarDelegate

extension S1ArchiveListViewController: UINavigationBarDelegate {
    public func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

// MARK: UISearchBarDelegate

extension S1ArchiveListViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.searchingTerm.value = searchText
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()

        guard
            let text = searchBar.text,
            let topicID: NSNumber = NumberFormatter().number(from: text)
        else {
            return
        }

        let topic = dataCenter.traced(topicID: topicID.intValue) ?? S1Topic(topicID: topicID)

        let contentViewController = ContentViewController(topic: topic)
        navigationController?.pushViewController(contentViewController, animated: true)
    }
}

// MARK: - Actions

extension S1ArchiveListViewController {
    @objc func segSelected() {
        viewModel.segmentControlIndexChanged(newValue: segControl.selectedSegmentIndex)
    }

    @objc func clearSearchBarText() {
        searchBar.text = ""
        searchBar.delegate?.searchBar?(self.searchBar, textDidChange: "")
    }

    override func didReceivePaletteChangeNotification(_ notification: Notification?) {
        view.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.background")

        tableView.separatorColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.separator")
        tableView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.background")
        tableView.indicatorStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .white : .default
        if let backgoundView = tableView.backgroundView {
            backgoundView.backgroundColor = AppEnvironment.current.colorManager.colorForKey("topiclist.tableview.background")
        }

        searchBar.searchBarStyle = AppEnvironment.current.colorManager.isDarkTheme() ? .minimal : .default
        searchBar.tintColor = AppEnvironment.current.colorManager.colorForKey("topiclist.searchbar.tint")
        searchBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("topiclist.searchbar.bartint")
        searchBar.keyboardAppearance = AppEnvironment.current.colorManager.isDarkTheme() ? .dark : .default
        if searchBar.isFirstResponder {
            searchBar.reloadInputViews()
        }

        navigationBar.barTintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.bartint")
        navigationBar.tintColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.tint")
        navigationBar.titleTextAttributes = [
            .foregroundColor: AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.title"),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ]

        setNeedsStatusBarAppearanceUpdate()
    }
}
