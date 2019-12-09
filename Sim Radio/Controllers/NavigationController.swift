//
//  NavigationController.swift
//  Sim Radio

import UIKit

class NavigationController: UINavigationController {
    weak var radio: Radio!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let seriesViewController = viewControllers.first as? SeriesViewController {
            seriesViewController.radio = radio
        }
        navigationBar.installBlurEffect()
        navigationBar.prefersLargeTitles = true
    }
}
