//
//  CardIndicatorView.swift
//  DeckTransition
//

import UIKit

open class CardIndicatorView: UIView {
    var style: Style = .line {
        didSet {
            switch style {
            case .line:
                animate {
                    self.leftView.transform = .identity
                    self.rightView.transform = .identity
                }
            case .arrow:
                animate {
                    let angle = CGFloat(20 * Float.pi / 180)
                    self.leftView.transform = CGAffineTransform(rotationAngle: angle)
                    self.rightView.transform = CGAffineTransform(rotationAngle: -angle)
                }
            }
        }
    }

    var color: UIColor = UIColor(red: 202 / 255, green: 201 / 255, blue: 207 / 255, alpha: 1) {
        didSet {
            leftView.backgroundColor = color
            rightView.backgroundColor = color
        }
    }

    private var leftView: UIView = UIView()
    private var rightView: UIView = UIView()

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor.clear
        addSubview(leftView)
        addSubview(rightView)
        color = UIColor(red: 202 / 255, green: 201 / 255, blue: 207 / 255, alpha: 1)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func sizeToFit() {
        super.sizeToFit()
        frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: 36, height: 13)

        let height: CGFloat = 5
        let correction = height / 2

        leftView.frame = CGRect(x: 0, y: 0, width: frame.width / 2 + correction, height: height)
        leftView.center.y = frame.height / 2
        leftView.layer.cornerRadius = min(leftView.frame.width, leftView.frame.height) / 2

        rightView.frame = CGRect(x: frame.width / 2 - correction, y: 0, width: frame.width / 2 + correction, height: height)
        rightView.center.y = frame.height / 2
        rightView.layer.cornerRadius = min(leftView.frame.width, leftView.frame.height) / 2
    }

    private func animate(animations: @escaping (() -> Void)) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            animations()
        })
    }

    enum Style {
        case arrow
        case line
    }
}
