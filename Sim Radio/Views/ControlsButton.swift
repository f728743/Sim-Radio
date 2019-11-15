//
//  ControlsButton.swift
//  Sim Radio
//

import UIKit

class ControlsButton: UIButton {
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        layer.cornerRadius = frame.width / 2
        clipsToBounds = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        animateButtonDown()
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        animateButtonUp()
        super.touchesEnded(touches, with: event)
    }

    func animateButtonDown() {
        layer.removeAllAnimations()
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.allowUserInteraction, .curveEaseIn], animations: {
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.backgroundColor = UIColor(white: 0.8, alpha: 0.5)
        }, completion: nil)
    }

    func animateButtonUp() {
        layer.removeAllAnimations()
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            self.transform = CGAffineTransform.identity
            self.backgroundColor = UIColor(white: 0.8, alpha: 0.0)
        }, completion: nil)
    }
}
