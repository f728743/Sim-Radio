//
//  ProgressIndicatorView.swift
//  ProgressIndicator
//

import UIKit

class ProgressIndicatorView: UIView {

    enum State {
        case new
        case progress(value: Double)
        case finished
    }

    var state: State = .new {
        didSet(newState) {
            if case let .progress(progress) = state {
                let strokeEnd = 1.0 - CGFloat(progress).clamped(to: 0.0...1.0)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                pieLayer.strokeEnd = strokeEnd
                CATransaction.commit()
            }
            updateVisibility()
        }
    }

    public var shadeColor: UIColor = .black {
        didSet {
            updateVisibility()
        }
    }

    override public var tintColor: UIColor! {
        didSet {
            updateVisibility()
        }
    }

    public var appearanceDuration: TimeInterval = 0.6
    public var disappearanceDuration: TimeInterval = 0.4
    public var opacity: Float = 0 {
        didSet {
            holeLayer.opacity = opacity
            pieLayer.opacity = opacity
            intactStateLayer.opacity = opacity
        }
    }
    private var size: CGFloat {
        return  min(layer.bounds.width, layer.bounds.height)
    }
    private let tintLayer = CALayer()
    private let intactStateLayer = CALayer()
    private let holeLayer = CAShapeLayer()
    private let pieLayer = CAShapeLayer()
    private var outerCircleRadius: CGFloat { return size / 3.0 }
    private var gapWidth: CGFloat { return (size / 3.0 - size / 3.5) }
    private var innerCircleRadius: CGFloat {
        return max(outerCircleRadius - gapWidth, 0.0)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.backgroundColor = UIColor.clear.cgColor
        setupLayers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.backgroundColor = UIColor.clear.cgColor
        setupLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        holeLayer.path = holePath(radius: outerCircleRadius)
        pieLayer.position = CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2)
        pieLayer.path = piePath(radius: innerCircleRadius)
        pieLayer.lineWidth = innerCircleRadius
        tintLayer.frame = layer.bounds
        intactStateLayer.frame = layer.bounds
    }

    private func updateVisibility() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch state {
        case .new:
            tintLayer.backgroundColor = tintColor.cgColor
            intactStateLayer.backgroundColor = shadeColor.cgColor
            pieLayer.strokeColor = UIColor.clear.cgColor
            holeLayer.path = holePath(radius: outerCircleRadius)
            holeLayer.fillColor = UIColor.clear.cgColor
        case .progress:
            tintLayer.backgroundColor = tintColor.cgColor
            intactStateLayer.backgroundColor = UIColor.clear.cgColor
            pieLayer.strokeColor = shadeColor.cgColor
            holeLayer.path = holePath(radius: outerCircleRadius)
            holeLayer.fillColor = shadeColor.cgColor
        case .finished:
            tintLayer.backgroundColor = UIColor.clear.cgColor
            intactStateLayer.backgroundColor = UIColor.clear.cgColor
            pieLayer.strokeColor = UIColor.clear.cgColor
            holeLayer.fillColor = shadeColor.cgColor
            let hypotenuse = (size * size / 2).squareRoot()
            holeLayer.path = holePath(radius: hypotenuse)
        }
        CATransaction.commit()
    }

    private func setupLayers() {
        holeLayer.path = holePath(radius: outerCircleRadius)
        holeLayer.fillRule = .evenOdd
        holeLayer.lineWidth = 0
        layer.addSublayer(holeLayer)

        pieLayer.path = piePath(radius: innerCircleRadius)
        pieLayer.position = CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2)
        pieLayer.lineWidth = innerCircleRadius
        pieLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(pieLayer)

        tintLayer.frame = layer.bounds
        tintLayer.backgroundColor = UIColor.white.cgColor
        tintLayer.opacity = 0.4
        tintLayer.zPosition = -1
        layer.addSublayer(tintLayer)

        intactStateLayer.frame = layer.bounds
        layer.addSublayer(intactStateLayer)

        layer.masksToBounds = true
        opacity = 0.6
    }

    func animateAppearance() {
        let piePathAnimation = CABasicAnimation(keyPath: "path")
        piePathAnimation.fromValue = piePath(radius: gapWidth)
        piePathAnimation.toValue = piePath(radius: innerCircleRadius)
        let pieLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        pieLineWidthAnimation.fromValue = gapWidth
        pieLineWidthAnimation.toValue = innerCircleRadius
        let pieAnimations = CAAnimationGroup()
        pieAnimations.animations = [piePathAnimation, pieLineWidthAnimation]
        pieAnimations.duration = appearanceDuration
        pieAnimations.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        pieLayer.add(pieAnimations, forKey: "pieAppearance")

        let holeAnimation = CABasicAnimation(keyPath: "path")
        holeAnimation.fromValue =  holePath(radius: gapWidth * 2)
        holeAnimation.toValue =  holePath(radius: outerCircleRadius)
        holeAnimation.duration = appearanceDuration
        holeLayer.add(holeAnimation, forKey: "holeAppearance")
    }

    func animateDisappearance() {
        let holeAnimation = CABasicAnimation(keyPath: "path")
        let hypotenuse = (size * size / 2).squareRoot()
        holeAnimation.fromValue = holePath(radius: outerCircleRadius)
        holeAnimation.toValue = holePath(radius: hypotenuse)
        holeAnimation.duration = disappearanceDuration
        holeLayer.add(holeAnimation, forKey: "holeDisappearance")

        let pieAnimation = CABasicAnimation(keyPath: "strokeColor")
        pieAnimation.fromValue = shadeColor.cgColor
        pieAnimation.toValue = UIColor.clear.cgColor
        pieAnimation.duration = disappearanceDuration
        pieLayer.add(pieAnimation, forKey: "pieDisappearance")

        let tintAnimation = CABasicAnimation(keyPath: "backgroundColor")
        tintAnimation.fromValue = tintColor.cgColor
        tintAnimation.toValue = UIColor.clear.cgColor
        tintAnimation.duration = disappearanceDuration
        tintLayer.add(tintAnimation, forKey: "tintDisappearance")
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
}
