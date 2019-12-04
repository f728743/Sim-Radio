//
//  ContextMenuLogoView.swift
//  RadioDownloader
//

import UIKit

class ContextMenuLogoView: UIView {

    var circleRadius: CGFloat = 24 {
        didSet {
            updateViewPositions()
        }
    }

    var image: UIImage? {
        get {
            return logoImageView.image
        }
        set {
            logoImageView.image = newValue
        }
    }

    private let logoImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 4
        view.layer.borderWidth = 1 / UIScreen.main.scale
        view.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        view.clipsToBounds = true
        return view
    }()

    private let playImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .center
        view.image = UIImage(named: "Mini Play")
        return view
    }()

    private let blurEffectView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        view.clipsToBounds = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(logoImageView)
        addSubview(blurEffectView)
        addSubview(playImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        updateViewPositions()
    }

    private func updateViewPositions() {
        logoImageView.frame = bounds
        blurEffectView.layer.cornerRadius = circleRadius
        let imageSize = logoImageView.frame.size
        let diameter = circleRadius * 2
        blurEffectView.frame = CGRect(
            origin: CGPoint(x: (imageSize.width - diameter) / 2, y: (imageSize.height - diameter) / 2),
            size: CGSize(width: diameter, height: diameter))
        playImageView.frame = bounds
    }
}
