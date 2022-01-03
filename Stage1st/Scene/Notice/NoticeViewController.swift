//
//  NoticeViewController.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import ReactiveSwift

class NoticeViewController: UIViewController {
    let viewModel: NoticeViewModel

    let layout = UICollectionViewFlowLayout()
    let navigationBar = UINavigationBar()
    let collectionView: UICollectionView
    private let emptyView = EmptyView()
    let refreshHUD = Hud(frame: .zero)

    let loadingIndicator = UIActivityIndicatorView(style: .medium)

    @objc
    convenience init() {
        self.init(viewModel: NoticeViewModel())
    }

    init(viewModel: NoticeViewModel) {
        self.viewModel = viewModel
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)

        super.init(nibName: nil, bundle: nil)

        title = "回复提醒"
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(backAction))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubviews()
        setupAutoLayout()
        setupBindings()

        NotificationCenter.default.reactive.notifications(forName: .APPaletteDidChange).producer
            .map { _ in () }
            .prefix(value: ())
            .startWithValues { [weak self] (_) in
                guard let strongSelf = self else { return }
                let colorManager = AppEnvironment.current.colorManager
                strongSelf.loadingIndicator.style = .medium
                strongSelf.collectionView.backgroundColor = colorManager.colorForKey("notice.background")

                strongSelf.navigationController?.navigationBar.barTintColor = colorManager.colorForKey("appearance.navigationbar.bartint")
                strongSelf.navigationController?.navigationBar.tintColor = colorManager.colorForKey("appearance.navigationbar.tint")
                strongSelf.navigationController?.navigationBar.titleTextAttributes = [
                    .foregroundColor: colorManager.colorForKey("appearance.navigationbar.title"),
                    .font: UIFont.boldSystemFont(ofSize: 17.0)
                ]

                strongSelf.collectionView.reloadData()

                strongSelf.setNeedsStatusBarAppearanceUpdate()
            }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppEnvironment.current.colorManager.isDarkTheme() ? .lightContent : .default
    }
}

// MARK: - Setup

extension NoticeViewController {

    private func setupSubviews() {

        navigationBar.isTranslucent = false
        navigationBar.delegate = self
        navigationBar.pushItem(self.navigationItem, animated: false)
        view.addSubview(navigationBar)

        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0

        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NoticeCell.self, forCellWithReuseIdentifier: "notice")
        view.addSubview(collectionView)

        view.addSubview(emptyView)

        view.addSubview(loadingIndicator)
    }

    private func setupAutoLayout() {
        view.addSubview(navigationBar)
        navigationBar.snp.makeConstraints({ (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalTo(self.view)
        })

        collectionView.snp.makeConstraints { (make) in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalTo(self.view)
        }

        loadingIndicator.snp.makeConstraints { (make) in
            make.center.equalTo(collectionView)
        }

        emptyView.snp.makeConstraints { (make) in
            make.edges.equalTo(collectionView)
        }
    }

    private func setupBindings() {

        viewModel.state.producer.startWithValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.collectionView.reloadData()
        }

        emptyView.reactive.isHidden <~ viewModel.isEmptyViewHidden
        loadingIndicator.reactive.isAnimating <~ viewModel.isLoadingIndicatorAnimating
    }
}

// MARK: - UINavigationBarDelegate

extension NoticeViewController: UINavigationBarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
// MARK: - Actions

extension NoticeViewController {

    @objc func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension NoticeViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItem()
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "notice", for: indexPath) as! NoticeCell
        let cellViewModel = viewModel.cellViewModel(at: indexPath.item)
        cell.configure(with: cellViewModel)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension NoticeViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 100.0)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cellViewModel = viewModel.cellViewModel(at: indexPath.item)

        refreshHUD.showLoadingIndicator()
        AppEnvironment.current.apiService.topic(with: cellViewModel.path) { [weak self] (result) in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let topic):
                strongSelf.refreshHUD.hide(delay: 0.0)
                let contentViewModel = ContentViewModel(topic: topic)
                let contentViewController = ContentViewController(viewModel: contentViewModel)
                strongSelf.navigationController?.pushViewController(contentViewController, animated: true)
            case .failure(let error):
                strongSelf.refreshHUD.show(message: "\(error.localizedDescription)")
                strongSelf.refreshHUD.hide(delay: 2.0)
            }
        }
    }
}

import Combine

private class EmptyView: UIView {
    let label = UILabel()

    private var bag = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.numberOfLines = 0

        AppEnvironment.current.settings.currentUsername
            .map { (username) -> String in
                return username == nil ? "未登录" : "无信息"
            }
            .assign(to: \.text, on: label)
            .store(in: &bag)

        label.textColor = AppEnvironment.current.colorManager.colorForKey("appearance.toolbar.tint")
        label.font = .boldSystemFont(ofSize: 18.0)
        addSubview(label)

        label.snp.makeConstraints { (make) in
            make.center.equalTo(self)
            make.left.greaterThanOrEqualTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

import SwiftUI

struct NoticeView: UIViewControllerRepresentable {

    func makeUIViewController(context: UIViewControllerRepresentableContext<NoticeView>) -> NoticeViewController {
        return NoticeViewController()
    }

    func updateUIViewController(_ uiViewController: NoticeViewController, context: UIViewControllerRepresentableContext<NoticeView>) {
    }
}

struct NoticeView_Previews: PreviewProvider {
    static var previews: some View {
        NoticeView()
    }
}
