//
//  NoticeCell.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/21.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import SnapKit
import Fuzi
import Kingfisher

class NoticeCell: UICollectionViewCell {

    let avatarImageView = UIImageView()
    let authorLabel = UILabel()
    let titleLabel = UILabel()
    let dateLabel = UILabel()
    var widthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        contentView.addSubview(avatarImageView)

        contentView.addSubview(dateLabel)

        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)

        avatarImageView.snp.makeConstraints { (make) in
            make.leading.top.equalTo(contentView).inset(8.0)
            make.width.height.equalTo(60.0)
            make.bottom.lessThanOrEqualTo(contentView).offset(-8.0)
        }

        dateLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(8.0)
            make.trailing.equalTo(contentView).offset(-8.0)
            make.top.equalTo(avatarImageView)
        }

        titleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(dateLabel.snp.bottom).offset(8.0)
            make.leading.equalTo(dateLabel)
            make.trailing.equalTo(contentView).offset(-8.0)
            make.bottom.equalTo(contentView)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
    }

    func configure(with viewModel: ViewModel) {
        if let avatarURL = viewModel.user.avatarURL {
            avatarImageView.kf.setImage(with: avatarURL)
        }

        titleLabel.text = viewModel.title
        dateLabel.text = viewModel.date.s1_gracefulDateTimeString()
//        widthConstraint?.update(offset: width)
        // "\(author.name) 于 \(date) 回复\n\(message) \n\(link)"
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let autoLayoutAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)

        // Specify you want _full width_
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0.0)

        // Calculate the size (height) using Auto Layout
        let autoLayoutSize = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        )
        let autoLayoutFrame = CGRect(origin: autoLayoutAttributes.frame.origin, size: autoLayoutSize)

        // Assign the new size to the layout attributes
        autoLayoutAttributes.frame = autoLayoutFrame
        return autoLayoutAttributes
    }
}

extension NoticeCell {
    struct ViewModel {
        let title: String
        let user: User
        let date: Date
        let path: String
        let isNew: Bool

        init(replyNotice: ReplyNotice) throws {
            let document = try HTMLDocument(string: replyNotice.note)
            let result = document.xpath("//a")

            guard let targetMessage = result.dropFirst().first else {
                throw "Failed to extract node."
            }

            guard let link = targetMessage.attributes["href"] else {
                throw "Failed to extract link."
            }

            let message = targetMessage.stringValue

            self.title = message
            self.path = link
            self.date = replyNotice.dateline
            self.user = User(id: replyNotice.authorid, name: replyNotice.author)
            self.isNew = replyNotice.new
        }
    }
}
