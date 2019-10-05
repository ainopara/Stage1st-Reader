//
//  DarkModeDetectWindow.swift
//  Stage1st
//
//  Created by Zheng Li on 2019/10/5.
//  Copyright © 2019 Renaissance. All rights reserved.
//

import Combine

final class DarkModeDetectWindow: UIWindow {

    let traitCollectionSubject: CurrentValueSubject<UITraitCollection, Never> = CurrentValueSubject(UITraitCollection.current)

    override init(frame: CGRect) {
        super.init(frame: frame)

        traitCollectionSubject.send(self.traitCollection)
    }

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)

        traitCollectionSubject.send(self.traitCollection)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            traitCollectionSubject.send(traitCollection)
        }
    }
}
