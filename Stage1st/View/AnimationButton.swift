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
        if tintColor == nil {
            return images.compactMap({ image in
                image.cgImage
            })
        }
        return images.compactMap({ templateImage in
            templateImage.s1_tintWithColor(self.tintColor).cgImage
        })
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: - Public
extension AnimationView {
    func removeAllAnimations() {
        S1LogDebug("stop animation")
        layer.removeAllAnimations()
        isPlayingAnimation = false
    }

    func reloadAnimation() {
        guard let animation = self.layer.animation(forKey: "ABAnimation") as? CAKeyframeAnimation else {
            S1LogDebug("start animation")
            startAnimation(self.animation())
            return
        }
        S1LogDebug("reload animation")
        pauseAnimation(animation)
        resumeAnimation(self.animation())
    }
}

// MARK: - Private
extension AnimationView {
    fileprivate func animation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.duration = 3.0
        animation.values = cgImages
        animation.repeatCount = HUGE
        animation.fillMode = kCAFillModeForwards
        return animation
    }
}

extension AnimationView {
    fileprivate func startAnimation(_ animation: CAKeyframeAnimation) {
        layer.add(animation, forKey: "ABAnimation")
        isPlayingAnimation = true
    }

    fileprivate func pauseAnimation(_ animation: CAKeyframeAnimation) {
        beginTime = animation.beginTime
        layer.removeAnimation(forKey: "ABAnimation")
        isPlayingAnimation = false
    }

    fileprivate func resumeAnimation(_ animation: CAKeyframeAnimation) {
        animation.beginTime = beginTime
        startAnimation(animation)
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

@objcMembers
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
                    animationView.tintColor = tintColor.withAlphaComponent(hightlightAlpha)
                } else {
                    animationView.tintColor = tintColor
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
                animationView.tintColor = tintColor.withAlphaComponent(hightlightAlpha)
            } else {
                animationView.tintColor = tintColor
            }
            recover()
        }
    }

    init(frame: CGRect, image: UIImage, images: [UIImage]) {
        self.image = image
        super.init(frame: frame)

        animationView.images = images
        setStaticImage(self.image)

        addSubview(animationView)
        animationView.snp.makeConstraints { make in
            make.center.equalTo(self)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        animationView.reloadAnimation()
        setStaticImage(nil)
    }

    func stopAnimation() {
        animationView.removeAllAnimations()
        setStaticImage(image)
    }

    /**
     When button is animating and removed from a navigation bar, animation will be stopped.
     Call this method when you decided to show the button again.
     */
    func recover() {
        if isPlayingAnimation {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    fileprivate func setStaticImage(_ image: UIImage?) {
        setImage(image?.s1_tintWithColor(tintColor), for: .normal)
        setImage(image?.s1_tintWithColor(tintColor.withAlphaComponent(hightlightAlpha)), for: .highlighted)
    }
}
