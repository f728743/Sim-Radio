//
//  PopMenuItemViewController.swift
//  Sim Radio
//

import UIKit

class PopMenuItemViewController: UIViewController {

    let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
        imageView.clipsToBounds = true
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(logoImageView)
        logoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16).isActive = true
        logoImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16).isActive = true
        logoImageView.widthAnchor.constraint(equalTo: logoImageView.heightAnchor).isActive = true

        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        label.trailingAnchor.constraint(equalTo: logoImageView.leadingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
