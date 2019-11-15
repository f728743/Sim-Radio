//
//  CardPresentingAnimationController.swift
//  DeckTransition
//

import UIKit

final class CardPresentingAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    public var initialHeight: CGFloat = 0
    public var cornerRadius: CGFloat = 10
    public var transitionDuration: TimeInterval = 0.6

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .to) else { return }

        let containerView = transitionContext.containerView
        containerView.addSubview(presentedViewController.view)

        let finalFrameForPresentedView = transitionContext.finalFrame(for: presentedViewController)
        presentedViewController.view.frame = finalFrameForPresentedView
        presentedViewController.view.frame.origin.y = containerView.bounds.height - initialHeight

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: [.curveEaseOut],
            animations: {
                presentedViewController.view.layer.cornerRadius = self.cornerRadius
                presentedViewController.view.frame = finalFrameForPresentedView
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            }
        )
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }
}
