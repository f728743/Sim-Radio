//
//  SeriesHeaderTableViewCell.swift
//  Sim Radio
//

import UIKit

class StationsHeaderTableViewCell: UITableViewCell {
    static let reuseId = "StationsHeaderTableViewCell"

    let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderWidth = 1 / UIScreen.main.scale
        imageView.layer.cornerRadius = 4
        imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        imageView.clipsToBounds = true
        return imageView
    }()

    let progressView: ProgressIndicatorView = {
        let indicator = ProgressIndicatorView()
        indicator.tintColor = UIColor.white
        indicator.shadeColor = UIColor.black
        indicator.layer.cornerRadius = 4
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none

        separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)

        addSubview(logoImageView)
        addSubview(progressView)
        addSubview(titleLabel)

        // logoImageView constraints
        logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 4).isActive = true
        logoImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16).isActive = true
        logoImageView.widthAnchor.constraint(equalTo: logoImageView.heightAnchor).isActive = true

        // progressView constraints
        progressView.leadingAnchor.constraint(equalTo: logoImageView.leadingAnchor).isActive = true
        progressView.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor).isActive = true
        progressView.topAnchor.constraint(equalTo: logoImageView.topAnchor).isActive = true
        progressView.bottomAnchor.constraint(equalTo: logoImageView.bottomAnchor).isActive = true

        // titleLabel constraints
        titleLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 8).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
