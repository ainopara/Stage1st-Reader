//
//  MahjongFaceInputView.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/9/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import HorizontalFloatingHeaderLayout
import ReactiveSwift

protocol MahjongFaceInputViewDelegate: class {
    func mahjongFaceInputView(_ inputView: MahjongFaceInputView, didTapItem item: MahjongFaceInputView.Category.Item)
    func mahjongFaceInputViewDidTapDeleteButton(_ inputView: MahjongFaceInputView)
}

final class MahjongFaceInputView: UIView {
    weak var delegate: MahjongFaceInputViewDelegate?
    let collectionView: UICollectionView
//    let tabBar: S1TabBar
    let decorationView: UIView

    struct Category: Codable {
        let id: String
        let name: String
        struct Item: Codable {
            let id: String
            let path: String
            let width: Int
            let height: Int
        }
        var content: [Item]
    }

    struct HistoryItem: Codable {
        let id: String

        init(id: String) {
            self.id = id
        }
    }

    let categories: MutableProperty<[Category]> = MutableProperty([])
    let historyCategory: MutableProperty<Category>

    let embeddedCategories: [Category]

    override init(frame: CGRect) {
        let layout = HorizontalFloatingHeaderLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
//        tabBar = S1TabBar(frame: .zero)
        decorationView = UIView()

        let categoryIndexFileURL = Bundle.main.bundleURL
            .appendingPathComponent("Mahjong", isDirectory: true)
            .appendingPathComponent("index").appendingPathExtension("json")

        embeddedCategories = try! JSONDecoder().decode([Category].self, from: Data(contentsOf: categoryIndexFileURL))
        let historyItems = AppEnvironment.current.cacheDatabaseManager.mahjongFaceHistory()
        let availableItems = embeddedCategories.flatMap { $0.content }
        let historyContent = historyItems
            .map { historyItem in availableItems.first(where: { $0.id == historyItem.id })}
            .compactMap { $0 }
        historyCategory = MutableProperty(Category(id: "Frequently Used", name: "常用", content: historyContent))

        super.init(frame: frame)

        setupSignal()

        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(
            MahjongFaceCell.self,
            forCellWithReuseIdentifier: "mahjong"
        )
        collectionView.register(
            MahjongFaceInputHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "header"
        )
        addSubview(collectionView)

        addSubview(decorationView)

        setupAutoLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let historyItems = self.historyCategory.value.content.map { HistoryItem(id: $0.id) }
        AppEnvironment.current.cacheDatabaseManager.set(mahjongFaceHistory: historyItems)
    }

    fileprivate func setupAutoLayout() {
        decorationView.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(self)
            if #available(iOS 11.0, *) {
                make.top.equalTo(self.safeAreaLayoutGuide.snp.bottom)
            } else {
                // Fallback on earlier versions
                make.height.equalTo(0)
            }
        }

        collectionView.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalTo(self)
            make.bottom.equalTo(decorationView.snp.top)
        }
    }

    fileprivate func setupSignal() {
        categories <~ historyCategory.map { [weak self] historyCategory in
            guard let strongSelf = self else { return [] }
            if historyCategory.content.count > 0 {
                return [historyCategory] + strongSelf.embeddedCategories
            } else {
                return strongSelf.embeddedCategories
            }
        }

        categories.signal.observeValues { [weak self] (_) in
            guard let strongSelf = self else { return }
            strongSelf.collectionView.reloadData()
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MahjongFaceInputView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.categories.value.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.categories.value[section].content.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mahjong", for: indexPath) as! MahjongFaceCell
        cell.configure(with: self.categories.value[indexPath.section].content[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! MahjongFaceInputHeaderView
            let category = self.categories.value[indexPath.section]
            cell.label.text = category.name
            cell.label.textColor = AppEnvironment.current.colorManager.colorForKey("appearance.navigationbar.title")
            return cell
        }

        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "empty", for: indexPath)
    }
}

// MARK: - HorizontalFloatingHeaderLayoutDelegate

extension MahjongFaceInputView: HorizontalFloatingHeaderLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, horizontalFloatingHeaderItemSizeAt indexPath: IndexPath) -> CGSize {
        let item = self.categories.value[indexPath.section].content[indexPath.item]
        return CGSize(width: max(item.width, 44), height: max(item.height, 44))
    }

    func collectionView(_ collectionView: UICollectionView, horizontalFloatingHeaderSizeAt section: Int) -> CGSize {
        return CGSize(width: 40.0, height: 30.0)
    }

    func collectionView(_ collectionView: UICollectionView, horizontalFloatingHeaderItemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }

    func collectionView(_ collectionView: UICollectionView, horizontalFloatingHeaderColumnSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
}

// MARK: - UICollectionViewDelegate

extension MahjongFaceInputView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = self.categories.value[indexPath.section].content[indexPath.item]

        var historyItems = self.historyCategory.value.content
        historyItems.removeAll(where: { $0.id == item.id })
        historyItems.insert(item, at: 0)
        historyItems = Array(historyItems.prefix(100))
        self.historyCategory.value.content = historyItems

        self.delegate?.mahjongFaceInputView(self, didTapItem: item)
    }
}

// MARK: -

extension MahjongFaceInputView.Category.Item {
    var url: URL {
        let baseURL = Bundle.main.bundleURL.appendingPathComponent("Mahjong", isDirectory: true)
        return baseURL.appendingPathComponent(path)
    }
}
