//
//  File.swift
//  Stage1st
//
//  Created by Zheng Li on 3/27/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation

class AnimationView: UIView {
    var beginTime: CFTimeInterval = 0.0
    var isPlayingAnimation: Bool = false
    var images: [UIImage] = []
    private var cgImages: [AnyObject] {
        if self.tintColor == nil {
            return images.flatMap({ image in
                return image.CGImage
            })
        }
        return images.flatMap({ templateImage in
            return templateImage.tintWithColor(self.tintColor).CGImage
        })
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.userInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func animation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.duration = 3.0
        animation.values = self.cgImages
        animation.repeatCount = HUGE
        animation.fillMode = kCAFillModeForwards
        return animation
    }

    private func startAnimation(animation: CAKeyframeAnimation) {
        self.layer.addAnimation(animation, forKey: "ABAnimation")
        self.isPlayingAnimation = true
    }

    func removeAllAnimations() {
        self.layer.removeAllAnimations()
        self.isPlayingAnimation = false
    }

    private func pauseAnimation(animation: CAKeyframeAnimation) {
        self.beginTime = animation.beginTime
        self.layer.removeAnimationForKey("ABAnimation")
        self.isPlayingAnimation = false
    }

    private func resumeAnimation(animation: CAKeyframeAnimation) {
        animation.beginTime = self.beginTime
        self.startAnimation(animation)
    }

    func reloadAnimation() {
        guard let animation = self.layer.animationForKey("ABAnimation") as? CAKeyframeAnimation else {
            self.startAnimation(self.animation())
            return
        }
        self.pauseAnimation(animation)
        self.resumeAnimation(self.animation())
    }

    override func intrinsicContentSize() -> CGSize {
        if let firstImage = self.images.first {
            return firstImage.size
        }
        return CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric)
    }
}
