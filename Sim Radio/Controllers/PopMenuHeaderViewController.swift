//
//  PopMenuHeaderViewController.swift
//  Sim Radio
//

import UIKit

class PopMenuHeaderViewController: UIViewController {

    let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(for: .title2, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderWidth = 0.2
        imageView.layer.cornerRadius = 4
        imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
        imageView.clipsToBounds = true
        return imageView
    }()

    // fuck around with UIAlertController layouts
    private let crutchImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(crutchImageView)
        crutchImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        crutchImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16).isActive = true
        crutchImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16).isActive = true
        crutchImageView.widthAnchor.constraint(equalToConstant: 0).isActive = true

        crutchImageView.image = createClearImage(size: CGSize(width: 1, height: 80))

        view.addSubview(logoImageView)
        logoImageView.leadingAnchor.constraint(equalTo: crutchImageView.trailingAnchor).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        logoImageView.widthAnchor.constraint(equalTo: logoImageView.heightAnchor).isActive = true
        logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 16).isActive = true
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 16).isActive = true
        label.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    private func createClearImage(size: CGSize) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.clear.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
