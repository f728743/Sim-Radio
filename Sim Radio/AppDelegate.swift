//
//  AppDelegate.swift
//  Sim Radio
//

import AVFoundation
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let radio = Radio()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UINavigationBar.appearance().shadowImage = UIImage()
        if let rootViewController = window?.rootViewController as? RootViewController {
            rootViewController.radio = radio
        }
        return true
    }
}
