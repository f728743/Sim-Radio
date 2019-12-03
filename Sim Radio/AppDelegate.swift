//
//  AppDelegate.swift
//  Sim Radio
//

import AVFoundation
import UIKit

//struct GlobalConstants {
//    static let systemPink = UIColor(red: 255 / 255, green: 45 / 255, blue: 85 / 255, alpha: 1)
//
//}

extension UIColor
{
    open class var systemPink: UIColor
    {
        return UIColor(red: 255 / 255, green: 45 / 255, blue: 85 / 255, alpha: 1.0)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let radio = Radio()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UINavigationBar.appearance().shadowImage = UIImage()
        if let rootViewController = window?.rootViewController as? RootViewController {
            rootViewController.radio = radio
        }
        return true
    }
}
