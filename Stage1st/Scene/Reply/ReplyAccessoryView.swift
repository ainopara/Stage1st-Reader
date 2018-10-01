//
//  ReplyAccessaryView.swift
//  Stage1st
//
//  Created by Zheng Li on 2/12/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

protocol ReplyAccessoryViewDelegate: class {
    func accessoryView(_ accessoryView: ReplyAccessoryView, didTappedMahjongFaceButton button: UIButton)
    func accessoryView(_ accessoryView: ReplyAccessoryView, didTappedMarkSpoilerButton button: UIButton)
}

class ReplyAccessoryView: UIView {
    let toolBar = UIToolbar(frame: .zero)
    private let faceButton = UIButton(type: .system)
    private let spoilerButton = UIButton(type: .system)

    weak var delegate: ReplyAccessoryViewDelegate?

    // MARK: - Life Cycle
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 35))

        // Setup faceButton
        faceButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        faceButton.setImage(UIImage(named: "MahjongFaceButton"), for: .normal)
        faceButton.addTarget(self, action: #selector(ReplyAccessoryView.toggleFace(_:)), for: .touchUpInside)
        let faceItem = UIBarButtonItem(customView: faceButton)

        // Setup spoilerButton
        spoilerButton.frame = CGRect(x: 0, y: 0, width: 44, height: 35)
        spoilerButton.setTitle("H", for: .normal)
        spoilerButton.addTarget(self, action: #selector(ReplyAccessoryView.insertSpoilerMark(_:)), for: .touchUpInside)
        let spoilerItem = UIBarButtonItem(customView: spoilerButton)

        // Setup toolBar
        let fixItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixItem.width = 26.0
        let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([flexItem, spoilerItem, fixItem, faceItem, flexItem], animated: false)
        addSubview(toolBar)

        toolBar.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = self.window {
            if #available(iOS 12.0, *) {
                // Nothing to do.
            } else if #available(iOS 11.0, *) {
                self.snp.remakeConstraints { (make) in
                    make.top.lessThanOrEqualTo(window.safeAreaLayoutGuide.snp.bottom).offset(-35.0)
                }
                toolBar.snp.remakeConstraints { (make) in
                    make.leading.trailing.top.equalTo(self)
                    make.height.equalTo(35.0)
                }
            } else {
                // Fallback on earlier versions
                self.snp.remakeConstraints { (make) in
                    make.height.equalTo(35.0)
                }
                toolBar.snp.remakeConstraints { (make) in
                    make.edges.equalTo(self)
                }
            }
        }
    }

    func removeExtraConstraints() {
        if #available(iOS 12.0, *) {
            // Nothing to do.
        } else if #available(iOS 11.0, *) {
            self.snp.removeConstraints()
        }
    }
}

// MARK: - Actions

extension ReplyAccessoryView {
    @objc func toggleFace(_ button: UIButton) {
        self.delegate?.accessoryView(self, didTappedMahjongFaceButton: button)
    }

    @objc func insertSpoilerMark(_ button: UIButton) {
        self.delegate?.accessoryView(self, didTappedMarkSpoilerButton: button)
    }
}
