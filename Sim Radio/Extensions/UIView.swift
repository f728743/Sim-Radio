//
//  UIView+Snapshot.swift
//  Sim Radio
//

import UIKit

extension UIView {
    func makeSnapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func addCornerRadiusAnimation(cornerRadius: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        animation.fromValue = layer.cornerRadius
        animation.toValue = cornerRadius
        animation.duration = duration
        layer.add(animation, forKey: "cornerRadius")
        layer.cornerRadius = cornerRadius
    }
}
