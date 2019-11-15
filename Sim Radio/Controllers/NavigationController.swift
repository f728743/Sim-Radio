//
//  NavigationController.swift
//  Sim Radio

import UIKit

class NavigationController: UINavigationController {
    weak var radio: Radio!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let libraryViewController = viewControllers.first as? LibraryViewController {
            libraryViewController.radio = radio
        }
        navigationBar.installBlurEffect()
    }
}
