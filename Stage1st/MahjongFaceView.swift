//
//  MahjongFaceView.swift
//  Stage1st
//
//  Created by Zheng Li on 16/04/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit

extension S1MahjongFaceView {

    func categories() -> [MahjongFaceCategory] {
        func indexPath() -> URL {
            return Bundle.main.bundleURL.appendingPathComponent("Mahjong", isDirectory: true).appendingPathComponent("index").appendingPathExtension("json")
        }

        func index() -> [Any] {
            return Array<Any>.s1_array(from: indexPath()) ?? []
        }

        return index().flatMap {
            guard let model = $0 as? [String: Any] else {
                return nil
            }

            return MahjongFaceCategory(dictionary: model)
        }
    }

    func categoriesWithHistory() -> [MahjongFaceCategory] {
        return [MahjongFaceCategory(id: "history", name: "历史", content: self.historyArray)] + categories()
    }

    func categoryNames() -> [String] {
        return mahjongCategories.map { $0.name }
    }

    func categoryIDs() -> [String] {
        return mahjongCategories.map { $0.id }
    }

    func category(withName name: String) -> MahjongFaceCategory? {
        return mahjongCategories.first { $0.name == name }
    }

    func category(withID id: String) -> MahjongFaceCategory? {
        return mahjongCategories.first { $0.id == id }
    }
}

class S1MahjongFaceButton: UIButton {
    var mahjongFaceItem: MahjongFaceItem?

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
