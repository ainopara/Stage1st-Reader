//
//  TopicListCell.swift
//  Stage1st
//
//  Created by Zheng Li on 13/08/2017.
//  Copyright © 2017 Renaissance. All rights reserved.
//

import UIKit
import SnapKit

struct TopicListCellViewModel {
    let topic: S1Topic
    let isPinningTop: Bool
    let attributedTitle: NSAttributedString
}

final class TopicListCell: UITableViewCell {
    let drawingSubview = S1TopicListCellSubView(frame: .zero)
    let titleLabel = UILabel(frame: .zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        drawingSubview.contentMode = .redraw
        contentView.addSubview(drawingSubview)
        drawingSubview.snp.makeConstraints { (make) in
            make.edges.equalTo(contentView)
        }

        contentView.addSubview(titleLabel)
        titleLabel.numberOfLines = 0
        titleLabel.snp.makeConstraints { (make) in
            make.trailing.equalTo(contentView).offset(-20.0)
            make.centerY.equalTo(contentView.snp.centerY)
            make.leading.equalTo(contentView.snp.leading).offset(70.0)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with model: TopicListCellViewModel) {
        accessibilityLabel = model.topic.title
        drawingSubview.topic = model.topic
        drawingSubview.pinningToTop = model.isPinningTop
        drawingSubview.setNeedsDisplay()
        titleLabel.attributedText = model.attributedTitle

        updateBackgroundColor()
        traitCollectionDidChange(nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        drawingSubview.highlighted = selected
        drawingSubview.setNeedsDisplay()

        updateBackgroundColor()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        drawingSubview.highlighted = highlighted
        drawingSubview.setNeedsDisplay()

        updateBackgroundColor()
    }

    func updateBackgroundColor() {
        let cellBackgroundColor: UIColor

        if drawingSubview.pinningToTop {
            cellBackgroundColor = drawingSubview.highlighted ?
                AppEnvironment.current.colorManager.colorForKey("topiclist.cell.pinningTopBackground.highlight") :
                AppEnvironment.current.colorManager.colorForKey("topiclist.cell.pinningTopBackground.normal")
        } else {
            cellBackgroundColor = drawingSubview.highlighted ?
                AppEnvironment.current.colorManager.colorForKey("topiclist.cell.background.highlight") :
                AppEnvironment.current.colorManager.colorForKey("topiclist.cell.background.normal")
        }

        self.backgroundColor = cellBackgroundColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        switch traitCollection.horizontalSizeClass {
        case .compact:
            titleLabel.snp.updateConstraints({ (make) in
                make.leading.equalTo(contentView.snp.leading).offset(70.0)
            })
        default:
            titleLabel.snp.updateConstraints({ (make) in
                make.leading.equalTo(contentView.snp.leading).offset(90.0)
            })
        }
    }
}
