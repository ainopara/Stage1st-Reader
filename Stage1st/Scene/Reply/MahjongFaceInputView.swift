//
//  MahjongFaceInputView.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/9/16.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import HorizontalFloatingHeaderLayout

protocol MahjongFaceInputViewDelegate: class {
    func mahjongFaceInputView(_ inputView: MahjongFaceInputView, didTapItem item: MahjongFaceItem)
    func mahjongFaceInputViewDidTapDeleteButton(_ inputView: MahjongFaceInputView)
}

final class MahjongFaceInputHeaderView: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .boldSystemFont(ofSize: 14.0)
        addSubview(label)

        label.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.snp.centerY)
            make.leading.equalTo(self.snp.leading).offset(4.0)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MahjongFaceInputView: UIView {
    weak var delegate: MahjongFaceInputViewDelegate?
    let collectionView: UICollectionView
    let tabBar: S1TabBar

    var categories: [MahjongFaceCategory]

    override init(frame: CGRect) {
        let layout = HorizontalFloatingHeaderLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        tabBar = S1TabBar(frame: .zero)

        let categoryIndexFileURL = Bundle.main.bundleURL
            .appendingPathComponent("Mahjong", isDirectory: true)
            .appendingPathComponent("index").appendingPathExtension("json")

        let categoryData: [[String: Any]] = Array.s1_array(fromJSONFileURL: categoryIndexFileURL) ?? []
        categories = [MahjongFaceCategory(id: "history", name: "历史", content: [])] + categoryData.compactMap { MahjongFaceCategory(dictionary: $0) }

        super.init(frame: frame)

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

        addSubview(tabBar)

        tabBar.snp.makeConstraints { (make) in
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
            make.bottom.equalTo(tabBar.snp.top)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UICollectionViewDataSource

extension MahjongFaceInputView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.categories.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.categories[section].content.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mahjong", for: indexPath) as! MahjongFaceCell
        cell.configure(with: self.categories[indexPath.section].content[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! MahjongFaceInputHeaderView
            let category = self.categories[indexPath.section]
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
        let item = self.categories[indexPath.section].content[indexPath.item]
        return CGSize(width: max(item.width, 44), height: max(item.height, 44))
    }

    func collectionView(_ collectionView: UICollectionView, horizontalFloatingHeaderSizeAt section: Int) -> CGSize {
        return CGSize(width: 100.0, height: 30.0)
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
        let item = self.categories[indexPath.section].content[indexPath.item]
        self.delegate?.mahjongFaceInputView(self, didTapItem: item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MahjongFaceInputView: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0.0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0.0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        return CGSize(width: 100.0, height: 30.0)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let item = self.categories[indexPath.section].content[indexPath.item]
        return CGSize(width: max(item.width, 44), height: max(item.height, 44))
    }
}
