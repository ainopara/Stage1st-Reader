//
//  MahjongFaceCell.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/1.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Alamofire
import Kingfisher

final class MahjongFaceCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)

    static let placeholderImage = UIImage(named: "MahjongFacePlaceholder")

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.center.equalTo(self.contentView)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        self.imageView.kf.cancelDownloadTask()
    }

    func configure(with item: MahjongFaceInputView.Category.Item) {
        imageView.kf.setImage(with: .provider(LocalFileImageDataProvider(fileURL: item.url)), placeholder: MahjongFaceCell.placeholderImage)
        imageView.snp.remakeConstraints { (make) in
            make.center.equalTo(contentView)
            make.width.equalTo(item.width)
            make.height.equalTo(item.height)
        }
    }
}
