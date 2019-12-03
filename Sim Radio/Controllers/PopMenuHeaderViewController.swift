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
//        imageView.layer.borderWidth = 0.2
//        imageView.layer.cornerRadius = 4
//        imageView.layer.borderColor = UIColor(white: 0, alpha: 0.3).cgColor
//        imageView.clipsToBounds = true
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(logoImageView)
        logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8).isActive = true
        logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8).isActive = true
        logoImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8).isActive = true
        logoImageView.widthAnchor.constraint(equalTo: logoImageView.heightAnchor).isActive = true
//        logoImageView.heightAnchor.constraint(equalToConstant: 112).isActive = true
//        view.heightAnchor.constraint(equalTo: 65).isActive = true

//         view.heightAnchor.constraint(equalToConstant: 112).isActive = true

        
        view.addSubview(label)
        label.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 8).isActive = true
        label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 8).isActive = true
        label.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
