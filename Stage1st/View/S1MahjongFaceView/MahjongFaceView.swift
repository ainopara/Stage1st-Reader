//
//  MahjongFaceView.swift
//  Stage1st
//
//  Created by Zheng Li on 16/04/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit

extension S1MahjongFaceView {

    // Note: This should be private, but changed to internal to make tests have access to it.
    internal func categories() -> [MahjongFaceCategory] {
        let categoryIndexFileURL = Bundle.main.bundleURL
            .appendingPathComponent("Mahjong", isDirectory: true)
            .appendingPathComponent("index").appendingPathExtension("json")

        // swiftlint:disable syntactic_sugar
        let categoryData = Array<[String: Any]>.s1_array(fromJSONFileURL: categoryIndexFileURL) ?? []
        // swiftlint:enable syntactic_sugar

        return categoryData.flatMap { MahjongFaceCategory(dictionary: $0) }
    }

    @objc func categoriesWithHistory() -> [MahjongFaceCategory] {
        return [MahjongFaceCategory(id: "history", name: "历史", content: self.historyArray)] + categories()
    }

    @objc func categoryNames() -> [String] {
        return mahjongCategories.map { $0.name }
    }

    @objc func categoryIDs() -> [String] {
        return mahjongCategories.map { $0.id }
    }

    @objc func category(withName name: String) -> MahjongFaceCategory? {
        return mahjongCategories.first { $0.name == name }
    }

    @objc func category(withID id: String) -> MahjongFaceCategory? {
        return mahjongCategories.first { $0.id == id }
    }
}

class S1MahjongFaceButton: UIButton {
    @objc var mahjongFaceItem: MahjongFaceItem?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }

        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
        }

        super.touchesEnded(touches, with: event)
    }
}
