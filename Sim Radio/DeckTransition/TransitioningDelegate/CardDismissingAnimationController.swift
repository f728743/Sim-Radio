//
//  CardDismissingAnimationController.swift
//  DeckTransition
//

import UIKit

final class CardDismissingAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    public var endingHeight: CGFloat = 0
    public var transitionDuration: TimeInterval = 0.6

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let finalFrameForPresentedView = transitionContext.finalFrame(for: presentedViewController)

        let containerView = transitionContext.containerView
        let offscreenFrame = CGRect(x: 0,
                                    y: containerView.bounds.height - endingHeight,
                                    width: finalFrameForPresentedView.width,
                                    height: finalFrameForPresentedView.height)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: [.curveEaseIn],
            animations: {
                presentedViewController.view.layer.cornerRadius = 0
                presentedViewController.view.frame = offscreenFrame
            }
        ) { finished in
            transitionContext.completeTransition(finished)
        }
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }
}
