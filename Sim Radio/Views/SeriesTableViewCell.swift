//
//  SeriesTableViewCell.swift
//  Sim Radio
//

import UIKit

class SeriesTableViewCell: UITableViewCell {
    static let reuseId = "SeriesTableViewCell"

    var state: ESTMusicIndicatorViewState = .stopped {
        didSet {
            logoFadeView.alpha = state == .stopped ? 0 : 0.3
            musicIndicator.state = state
            logoFadeView.backgroundColor = .black
        }
    }

    var stationID = UUID()

    let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderWidth = 0.2
        imageView.layer.cornerRadius = 3
        imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        imageView.clipsToBounds = true
        return imageView
    }()

    let logoFadeView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 3
        view.clipsToBounds = true
        view.backgroundColor = .black
        view.alpha = 0
        return view
    }()

    let musicIndicator: ESTMusicIndicatorView = {
        let indicator = ESTMusicIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.tintColor = .white
        return indicator
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gray
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        separatorInset = UIEdgeInsets(top: 0, left: 84, bottom: 0, right: 0)

        addSubview(logoImageView)
        addSubview(logoFadeView)
        addSubview(musicIndicator)
        addSubview(titleLabel)
        addSubview(infoLabel)

        // logoImageView constraints
        logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 4).isActive = true
        logoImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4).isActive = true
        logoImageView.widthAnchor.constraint(equalTo: logoImageView.heightAnchor).isActive = true

        // logoFadeView constraints
        logoFadeView.leadingAnchor.constraint(equalTo: logoImageView.leadingAnchor).isActive = true
        logoFadeView.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor).isActive = true
        logoFadeView.topAnchor.constraint(equalTo: logoImageView.topAnchor).isActive = true
        logoFadeView.bottomAnchor.constraint(equalTo: logoImageView.bottomAnchor).isActive = true

        // logoFadeView constraints
        musicIndicator.leadingAnchor.constraint(equalTo: logoImageView.leadingAnchor).isActive = true
        musicIndicator.trailingAnchor.constraint(equalTo: logoImageView.trailingAnchor).isActive = true
        musicIndicator.topAnchor.constraint(equalTo: logoImageView.topAnchor).isActive = true
        musicIndicator.bottomAnchor.constraint(equalTo: logoImageView.bottomAnchor).isActive = true

        // titleLabel constraints
        titleLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 16).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true

        // infoLabel constraints
        infoLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 16).isActive = true
        infoLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        infoLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
