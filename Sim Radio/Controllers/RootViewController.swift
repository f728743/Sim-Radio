//
//  RootViewController.swift
//  Sim Radio
//

import UIKit

struct MiniPlayerConstants {
    static fileprivate(set) var safeAreaBottomInsets: CGFloat = 0
    static let height: CGFloat = 64
    static var fullHeight: CGFloat {
        return height + safeAreaBottomInsets
    }
}

class RootViewController: UIViewController {
    weak var radio: Radio!
    var miniPlayer: MiniPlayerViewController?
    @IBOutlet weak var miniPlayerHeight: NSLayoutConstraint!

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 11.0, *) {
            if let bottomPadding = UIApplication.shared.keyWindow?.safeAreaInsets.bottom {
                MiniPlayerConstants.safeAreaBottomInsets = bottomPadding
            }
        }
        miniPlayerHeight.constant = MiniPlayerConstants.fullHeight
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "navigationController" {
            if let nc = segue.destination as? NavigationController {
                nc.radio = radio
            }
        }

        if segue.identifier == "miniPlayerController" {
            if let mp = segue.destination as? MiniPlayerViewController {
                mp.radio = radio
                mp.delegate = self
                miniPlayer = mp
            }
        }
    }
}

extension RootViewController: MiniPlayerDelegate {
    func expand() {
        guard let modal = storyboard?.instantiateViewController(
            withIdentifier: "PlayerCardViewController"
            )
            as? PlayerCardViewController else {
                assertionFailure("No view controller ID PlayerCardViewController in storyboard")
                return
        }

        let transitionDelegate = CardTransitioningDelegate()
        transitionDelegate.transitionDuration = 0.6
        if let miniPlayer = self.miniPlayer {
            transitionDelegate.presentInitialHeight = MiniPlayerConstants.fullHeight
            transitionDelegate.dismissEndingHeight = MiniPlayerConstants.fullHeight
            modal.sourceView = miniPlayer
        }
        modal.transitionDuration = transitionDelegate.transitionDuration
        modal.transitioningDelegate = transitionDelegate
        modal.modalPresentationStyle = .custom
        modal.radio = radio
        present(modal, animated: true)
    }
}
