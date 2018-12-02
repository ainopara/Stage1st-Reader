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
    let collectionView: UICollectionView
    let closeButton = UIButton()

    init(viewModel: NoticeViewModel) {
        self.viewModel = viewModel
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)

        super.init(nibName: nil, bundle: nil)

        closeButton.setImage(UIImage(named: "Close"), for: .normal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubviews()
        setupAutoLayout()
        setupBindings()
    }
}

// MARK: - Setup

extension NoticeViewController {
    private func setupSubviews() {
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0

        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NoticeCell.self, forCellWithReuseIdentifier: "notice")
        view.addSubview(collectionView)
    }

    private func setupAutoLayout() {
        collectionView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
    }

    private func setupBindings() {
        closeButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.dismiss(animated: true, completion: nil)
        }

        viewModel.state.producer.startWithValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.collectionView.reloadData()
        }
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

        let contentViewModel = ContentViewModel(topic: S1Topic(topicID: 0))
        let contentViewController = ContentViewController(viewModel: contentViewModel)
        navigationController?.pushViewController(contentViewController, animated: true)
    }
}
