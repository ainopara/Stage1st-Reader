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
    var images: [UIImage] = [] {
        didSet { if isPlayingAnimation { startOrReloadAnimation() } }
    }

    var isPlayingAnimation: Bool = false

    private var cgImages: [CGImage] {
        if tintColor == nil {
            return images.compactMap({ image in
                image.cgImage
            })
        } else {
            return images.compactMap({ templateImage in
                templateImage.s1_tintWithColor(self.tintColor).cgImage
            })
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        isUserInteractionEnabled = false
    }
}

// MARK: Public
extension AnimationView {
    func stopAnimation() {
        S1LogDebug("stop animation")
        layer.removeAllAnimations()
        isPlayingAnimation = false
    }

    func startOrReloadAnimation() {
        if let animation = self.layer.animation(forKey: "ABAnimation") as? CAKeyframeAnimation {
            S1LogDebug("reload animation")
            pauseAnimation(animation)
            resumeAnimation(self.animation())
        } else {
            S1LogDebug("start animation")
            startAnimation(self.animation())
        }
    }
}

// MARK: Private
private extension AnimationView {
    func animation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.duration = 3.0
        animation.values = cgImages
        animation.repeatCount = HUGE
        animation.fillMode = CAMediaTimingFillMode.forwards
        return animation
    }
}

private extension AnimationView {
    func startAnimation(_ animation: CAKeyframeAnimation) {
        layer.add(animation, forKey: "ABAnimation")
        isPlayingAnimation = true
    }

    func pauseAnimation(_ animation: CAKeyframeAnimation) {
        beginTime = animation.beginTime
        layer.removeAnimation(forKey: "ABAnimation")
        isPlayingAnimation = false
    }

    func resumeAnimation(_ animation: CAKeyframeAnimation) {
        animation.beginTime = beginTime
        layer.add(animation, forKey: "ABAnimation")
        isPlayingAnimation = true
    }
}

// MARK: Override

extension AnimationView {
    override var intrinsicContentSize: CGSize {
        if let firstImage = self.images.first {
            return firstImage.size
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

// MARK: -

@objcMembers
class AnimationButton: UIButton {
    var hightlightAlpha: CGFloat = 0.4
    private let image: UIImage
    var animatedImages: [UIImage] {
        get { return animationView.images }
        set { animationView.images = newValue }
    }

    private let animationView = AnimationView(frame: CGRect.zero)

    var isPlayingAnimation: Bool {
        return animationView.isPlayingAnimation
    }

    private var previousHighlighted: Bool = false

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted != previousHighlighted {
                if isHighlighted {
                    animationView.tintColor = tintColor.withAlphaComponent(hightlightAlpha)
                } else {
                    animationView.tintColor = tintColor
                }
                if animationView.isPlayingAnimation {
                    animationView.startOrReloadAnimation()
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
            recoverAnimation()
        }
    }

    init(frame: CGRect, image: UIImage) {
        self.image = image
        super.init(frame: frame)

        animatedImages = [image]
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
        animationView.startOrReloadAnimation()
        setStaticImage(nil)
    }

    func stopAnimation() {
        animationView.stopAnimation()
        setStaticImage(image)
    }

    /**
     When button is animating and removed from a navigation bar, animation will be stopped.
     Call this method when you decided to show the button again.
     */
    func recoverAnimation() {
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
