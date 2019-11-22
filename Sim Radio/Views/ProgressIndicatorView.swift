//
//  ProgressIndicatorView.swift
//  ProgressIndicator
//

import UIKit

class ProgressIndicatorView: UIView {
    override public var tintColor: UIColor! {
        didSet {
            updateVisibility()
        }
    }
    public var value: Float = 0.0 {
        willSet(newValue) {
            isPieVisible = newValue > 0.0
            if value == 0.0 && newValue > 0.0 && newValue < 1.0 {
                animateAppearance()
            }
            if newValue >= 1.0 {
                animateDisappearance()
            }
            animateProgress(from: value.clamped(to: 0.0...1.0),
                            to: newValue.clamped(to: 0.0...1.0))
        }
    }
    public var progressAnimationDuration: TimeInterval = 1.0
    public var appearanceDuration: TimeInterval = 0.5
    public var disappearanceDuration: TimeInterval = 0.3
    public var opacity: Float {
        didSet {
            updateVisibility()
        }
    }
    private var size: CGFloat {
        return  min(layer.bounds.width, layer.bounds.height)
    }
    private let backgroundLayer = CALayer()
    private let holeLayer = CAShapeLayer()
    private let pieLayer = CAShapeLayer()
    private var outerCircleRadius: CGFloat { return size / 3.0 }
    private var gapWidth: CGFloat { return (size / 3.0 - size / 3.5) }
    private var innerCircleRadius: CGFloat {
        return max(outerCircleRadius - gapWidth, 0.0)
    }
    private var isPieVisible: Bool {
        willSet(newValue) {
            if isPieVisible != newValue {
                setPieVisible(newValue)
            }
        }
    }

    public override init(frame: CGRect) {
        opacity = 0.6
        isPieVisible = false
        super.init(frame: frame)
        layer.backgroundColor = UIColor.clear.cgColor
        setupLayers()
        updateVisibility()
    }

    required init?(coder aDecoder: NSCoder) {
        opacity = 0.6
        isPieVisible = false
        super.init(coder: aDecoder)
        layer.backgroundColor = UIColor.clear.cgColor
        setupLayers()
        updateVisibility()
        layer.cornerRadius = 15
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSize()
    }

    private func updateVisibility() {
        setPieVisible(isPieVisible)
    }

    private func setPieVisible(_ visible: Bool) {
        holeLayer.opacity = opacity
        pieLayer.opacity = opacity
        backgroundLayer.opacity = opacity
        backgroundLayer.backgroundColor = visible ? UIColor.clear.cgColor : tintColor.cgColor
        let indicatorColor = visible ? tintColor.cgColor : UIColor.clear.cgColor
        pieLayer.strokeColor = indicatorColor
        holeLayer.fillColor = indicatorColor
    }

    private func setupLayers() {
        holeLayer.fillRule = .evenOdd
        holeLayer.lineWidth = 0
        layer.addSublayer(holeLayer)

        pieLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(pieLayer)

        layer.addSublayer(backgroundLayer)
        layer.masksToBounds = true
    }

    private func updateSize() {
        holeLayer.path = holePath(radius: gapWidth * 2)
        pieLayer.position = CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2)
        pieLayer.path = piePath(radius: gapWidth)
        pieLayer.lineWidth = gapWidth
        backgroundLayer.frame = layer.bounds
    }

    private func animateProgress(from: Float, to: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        let toValue = 1.0 - to
        let fromValue = 1.0 - from
        animation.duration = progressAnimationDuration * Double(max(from, to) - min(from, to))
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        pieLayer.strokeEnd = CGFloat(toValue)
        pieLayer.add(animation, forKey: "animateprogress")
    }

    private func holePath(radius: CGFloat) -> CGPath {
        let bounds = CGRect(x: (layer.bounds.width - radius * 2) / 2,
                                y: (layer.bounds.height - radius * 2) / 2,
                                width: radius * 2,
                                height: radius * 2)
        let path = UIBezierPath(roundedRect: layer.bounds, cornerRadius: 0)
        path.append(UIBezierPath(roundedRect: bounds, cornerRadius: radius))
        path.usesEvenOddFillRule = true
        return path.cgPath
    }

    private func piePath(radius: CGFloat) -> CGPath {
        return UIBezierPath(arcCenter: CGPoint(x: 0.0, y: 0.0),
                            radius: radius / 2,
                            startAngle: CGFloat.pi * 3 / 2,
                            endAngle: -CGFloat.pi / 2,
                            clockwise: false).cgPath
    }

    func animateAppearance() {
        isPieVisible = true

        pieLayer.removeAllAnimations()
        let piePathAnimation = CABasicAnimation(keyPath: "path")
        piePathAnimation.toValue = piePath(radius: innerCircleRadius)
        let pieLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        pieLineWidthAnimation.toValue = innerCircleRadius
        let pieAnimation = CAAnimationGroup()
        pieAnimation.animations = [piePathAnimation, pieLineWidthAnimation]
        pieAnimation.isRemovedOnCompletion = false
        pieAnimation.duration = appearanceDuration
        pieAnimation.fillMode = .forwards
        pieAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        pieLayer.add(pieAnimation, forKey: "pieAppearance")

        holeLayer.removeAllAnimations()
        let holeAnimation = CABasicAnimation(keyPath: "path")
        holeAnimation.toValue =  holePath(radius: outerCircleRadius)
        holeAnimation.isRemovedOnCompletion = false
        holeAnimation.duration = appearanceDuration
        holeAnimation.fillMode = .forwards
        holeLayer.add(holeAnimation, forKey: "holeAppearance")
    }

    func animateDisappearance() {
        let animation = CABasicAnimation(keyPath: "path")
        let hypotenuse = (size * size / 2).squareRoot()
        animation.toValue =  holePath(radius: hypotenuse)
        animation.duration = disappearanceDuration
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        holeLayer.add(animation, forKey: "holeDisappearance")
    }

}
