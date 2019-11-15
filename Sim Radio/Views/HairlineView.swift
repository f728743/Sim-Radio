//
//  HairlineView.swift
//  Sim Radio
//

import UIKit

class HairlineView: UIView {
    override func awakeFromNib() {
        guard let backgroundColor = self.backgroundColor?.cgColor else { return }
        layer.borderColor = backgroundColor
        layer.borderWidth = (1.0 / UIScreen.main.scale) / 2
        self.backgroundColor = .clear
    }
}
