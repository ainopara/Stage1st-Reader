//
//  MahjongFaceCell.swift
//  Stage1st
//
//  Created by Zheng Li on 2018/10/1.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Alamofire
import AlamofireImage
import JTSImageViewController

final class MahjongFaceCell: UICollectionViewCell {
    let imageView = UIImageView(frame: .zero)

    static let imageDownloader: ImageDownloader = {
        let downloader = ImageDownloader()

        downloader.imageResponseSerializer = DataResponseSerializer { request, response, data, error in
            guard error == nil else { return .failure(error!) }

            if let image = JTSAnimatedGIFUtility.animatedImage(withAnimatedGIFData: data) {
                return .success(image)
            } else {
                return DataRequest.imageResponseSerializer().serializeResponse(request, response, data, error)
            }
        }

        return downloader
    }()

    static let placeholderImage = UIImage(named: "MahjongFacePlaceholder")

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.af_imageDownloader = MahjongFaceCell.imageDownloader
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.center.equalTo(self.contentView)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: MahjongFaceItem) {
        self.imageView.af_setImage(withURL: item.url, placeholderImage: MahjongFaceCell.placeholderImage)
        self.imageView.snp.remakeConstraints { (make) in
            make.center.equalTo(self.contentView)
            make.width.equalTo(item.width)
            make.height.equalTo(item.height)
        }
    }
}
