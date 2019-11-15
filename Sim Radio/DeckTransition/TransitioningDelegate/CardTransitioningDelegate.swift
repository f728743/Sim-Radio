//
//  CardTransitioningDelegate.swift
//  DeckTransition
//

import UIKit

public final class CardTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    public var cornerRadius: CGFloat = 10
    public var transitionDuration: TimeInterval = 0.6
    public weak var cardDelegate: CardControllerDelegate?
    public var presentInitialHeight: CGFloat = 0
    public var dismissEndingHeight: CGFloat = 0

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source _: UIViewController) -> UIPresentationController? {
        let controller = CardPresentationController(presentedViewController: presented, presenting: presenting)
        controller.cornerRadius = cornerRadius
        controller.transitioningDelegate = self

        controller.cardDelegate = cardDelegate
        return controller
    }

    public func animationController(forPresented presented: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let presentingController = CardPresentingAnimationController()
        presentingController.initialHeight = presentInitialHeight
        presentingController.cornerRadius = cornerRadius
        presentingController.transitionDuration = transitionDuration
        return presentingController
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let dismissingController = CardDismissingAnimationController()
        dismissingController.transitionDuration = transitionDuration
        dismissingController.endingHeight = dismissEndingHeight
        return dismissingController
    }
}
