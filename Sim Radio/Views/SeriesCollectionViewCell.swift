//
//  SeriesCollectionViewCell.swift
//  Sim Radio
//

import UIKit

class SeriesCollectionViewCell: UICollectionViewCell {
    static let reuseId = "SeriesCollectionViewCell"

    var appearance: LibraryItemAppearance? {
        didSet {
            if let appearance = appearance {
                logoImageView.image = appearance.logo
                titleLabel.text = appearance.title
                activityIndicator.stopAnimating()
            } else {
                logoImageView.image = UIImage(named: "Cover Artwork")
                titleLabel.text = ""
                activityIndicator.startAnimating()
            }
        }
    }

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 4
        imageView.layer.borderWidth = 0.2
        imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.style = .whiteLarge
        return indicator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(activityIndicator)
        activityIndicator.layer.zPosition = 1

        // logoImageView constraints
        logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        logoImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        logoImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        logoImageView.heightAnchor.constraint(equalTo: widthAnchor).isActive = true

        // titleLabel constraints
        titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        // activityIndicator constraints
        activityIndicator.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        activityIndicator.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        activityIndicator.topAnchor.constraint(equalTo: topAnchor).isActive = true
        activityIndicator.heightAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
