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
                if let downloadProgress = appearance.downloadProgress {
                    progressView.isHidden = false
                    if downloadProgress == 0 {
                        progressView.state = .new
                    } else if downloadProgress == 1.0 {
                        progressView.state = .finished
                    } else {
                        progressView.state = .progress(value: downloadProgress)
                    }
                } else {
                    progressView.isHidden = true
                }
                spinner.stopAnimating()
            } else {
                logoImageView.image = UIImage(named: "Cover Artwork")
                titleLabel.text = ""
                spinner.startAnimating()
                progressView.isHidden = true
            }
        }
    }

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 4
        imageView.layer.borderWidth = 1 / UIScreen.main.scale
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

    private let spinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.style = .whiteLarge
        return indicator
    }()

    let progressView: ProgressIndicatorView = {
        let indicator = ProgressIndicatorView()
        indicator.tintColor = UIColor.white
        indicator.shadeColor = UIColor.black
        indicator.layer.cornerRadius = 4
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(logoImageView)
        addSubview(progressView)
        addSubview(titleLabel)
        addSubview(spinner)
        bringSubviewToFront(spinner)

        // logoImageView constraints
        logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        logoImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        logoImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        logoImageView.heightAnchor.constraint(equalTo: widthAnchor).isActive = true

        // progressView constraints
        progressView.leadingAnchor.constraint(equalTo: logoImageView.leadingAnchor).isActive = true
        progressView.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor).isActive = true
        progressView.topAnchor.constraint(equalTo: logoImageView.topAnchor).isActive = true
        progressView.bottomAnchor.constraint(equalTo: logoImageView.bottomAnchor).isActive = true

        // titleLabel constraints
        titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        // spinner constraints
        spinner.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
