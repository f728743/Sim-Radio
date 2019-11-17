//
//  RootViewController.swift
//  Sim Radio
//

import UIKit

class RootViewController: UIViewController {
    weak var radio: Radio!
    var miniPlayer: MiniPlayerViewController?

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
            let height = miniPlayer.view.frame.height
            transitionDelegate.presentInitialHeight = height
            transitionDelegate.dismissEndingHeight = height
            modal.sourceView = miniPlayer
        }
        modal.transitionDuration = transitionDelegate.transitionDuration
        modal.transitioningDelegate = transitionDelegate
        modal.modalPresentationStyle = .custom
        modal.radio = radio
        present(modal, animated: true, completion: nil)
    }
}
