//
//  File.swift
//  Stage1st
//
//  Created by Zheng Li on 3/27/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack

class AnimationView: UIView {
    var beginTime: CFTimeInterval = 0.0
    var isPlayingAnimation: Bool = false
    var images: [UIImage] = []
    fileprivate var cgImages: [AnyObject] {
        if self.tintColor == nil {
            return images.flatMap({ image in
                return image.cgImage
            })
        }
        return images.flatMap({ templateImage in
            return templateImage.s1_tintWithColor(self.tintColor).cgImage
        })
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
// MARK: - Public
extension AnimationView {
    func removeAllAnimations() {
        DDLogDebug("[AnimationButton] stop animation")
        self.layer.removeAllAnimations()
        self.isPlayingAnimation = false
    }

    func reloadAnimation() {
        guard let animation = self.layer.animation(forKey: "ABAnimation") as? CAKeyframeAnimation else {
            DDLogDebug("[AnimationButton] start animation")
            self.startAnimation(self.animation())
            return
        }
        DDLogDebug("[AnimationButton] reload animation")
        self.pauseAnimation(animation)
        self.resumeAnimation(self.animation())
    }
}
// MARK: - Private
extension AnimationView {
    fileprivate func animation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.duration = 3.0
        animation.values = self.cgImages
        animation.repeatCount = HUGE
        animation.fillMode = kCAFillModeForwards
        return animation
    }
}

extension AnimationView {
    fileprivate func startAnimation(_ animation: CAKeyframeAnimation) {
        self.layer.add(animation, forKey: "ABAnimation")
        self.isPlayingAnimation = true
    }

    fileprivate func pauseAnimation(_ animation: CAKeyframeAnimation) {
        self.beginTime = animation.beginTime
        self.layer.removeAnimation(forKey: "ABAnimation")
        self.isPlayingAnimation = false
    }

    fileprivate func resumeAnimation(_ animation: CAKeyframeAnimation) {
        animation.beginTime = self.beginTime
        self.startAnimation(animation)
    }
}

// MARK: - override

extension AnimationView {
    override var intrinsicContentSize: CGSize {
        if let firstImage = self.images.first {
            return firstImage.size
        }
        return CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric)
    }
}

class AnimationButton: UIButton {
    var hightlightAlpha: CGFloat = 0.4
    fileprivate let image: UIImage
    fileprivate let animationView: AnimationView = AnimationView(frame: CGRect.zero)
    var isPlayingAnimation: Bool {
        return animationView.isPlayingAnimation
    }
    fileprivate var previousHighlighted: Bool = false
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted != previousHighlighted {
                if isHighlighted {
                    animationView.tintColor = self.tintColor.withAlphaComponent(self.hightlightAlpha)
                } else {
                    animationView.tintColor = self.tintColor
                }
                if animationView.isPlayingAnimation {
                    animationView.reloadAnimation()
                }
                previousHighlighted = isHighlighted
            }
        }
    }
    override var tintColor: UIColor! {
        didSet {
            if isHighlighted {
                animationView.tintColor = self.tintColor.withAlphaComponent(self.hightlightAlpha)
            } else {
                animationView.tintColor = self.tintColor
            }
            self.recover()
        }
    }

    init(frame: CGRect, image: UIImage, images: [UIImage]) {
        self.image = image
        super.init(frame: frame)

        self.animationView.images = images
        self.setStaticImage(self.image)

        self.addSubview(animationView)
        animationView.snp.makeConstraints { (make) in
            make.center.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        self.animationView.reloadAnimation()
        self.setStaticImage(nil)
    }

    func stopAnimation() {
        self.animationView.removeAllAnimations()
        self.setStaticImage(self.image)
    }

    /**
     When button is animating and removed from a navigation bar, animation will be stopped.
     Call this method when you decided to show the button again.
     */
    func recover() {
        if isPlayingAnimation {
            self.startAnimation()
        } else {
            self.stopAnimation()
        }
    }

    fileprivate func setStaticImage(_ image: UIImage?) {
        self.setImage(image?.s1_tintWithColor(self.tintColor), for: .normal)
        self.setImage(image?.s1_tintWithColor(self.tintColor.withAlphaComponent(self.hightlightAlpha)), for: .highlighted)
    }
}
