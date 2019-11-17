//
//  CardPresentationController.swift
//  DeckTransition
//

import UIKit

class CardPresentationController: UIPresentationController, UIGestureRecognizerDelegate {
    var swipeToDismissEnabled: Bool = true
    var tapAroundToDismissEnabled: Bool = true
    var showIndicator: Bool = true
    var indicatorColor: UIColor = UIColor(red: 202 / 255, green: 201 / 255, blue: 207 / 255, alpha: 1)
    var hideIndicatorWhenScroll: Bool = false
    var translateForDismiss: CGFloat = 200
    var hapticMoments: [CardHapticMoments] = [.willDismissIfRelease]

    var transitioningDelegate: UIViewControllerTransitioningDelegate?
    weak var cardDelegate: CardControllerDelegate?

    var pan: UIPanGestureRecognizer?
    var tap: UITapGestureRecognizer?

    private var indicatorView = CardIndicatorView()
    private var gradeView: UIView = UIView()
    private let snapshotViewContainer = UIView()
    private var snapshotView: UIView?
    private let backgroundView = UIView()

    private var snapshotViewTopConstraint: NSLayoutConstraint?
    private var snapshotViewWidthConstraint: NSLayoutConstraint?
    private var snapshotViewAspectRatioConstraint: NSLayoutConstraint?

    private var workGester: Bool = false
    private var startDismissing: Bool = false
    private var afterReleaseDismissing: Bool = false

    private let topSpace = UIApplication.shared.statusBarFrame.height

    private let alpha: CGFloat = 0.51
    var cornerRadius: CGFloat = 10

    private var scaleForPresentingView: CGFloat {
        guard let containerView = containerView else { return 0 }
        let factor = 1 - ((cornerRadius + 3) * 2 / containerView.frame.width)
        return factor
    }

    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    override var presentedView: UIView? {
        let view = self.presentedViewController.view
        if view?.frame.origin == CGPoint.zero {
            view?.frame = self.frameOfPresentedViewInContainerView
        }
        return view
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        let baseY: CGFloat = self.topSpace + 13
        let height: CGFloat = containerView.bounds.height - baseY
        return CGRect(x: 0, y: containerView.bounds.height - height, width: containerView.bounds.width, height: height)
    }

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        if !hapticMoments.isEmpty {
            feedbackGenerator.prepare()
        }

        guard let containerView = self.containerView,
            let presentedView = self.presentedView,
            let window = containerView.window else { return }

        if showIndicator {
            indicatorView.color = indicatorColor
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapIndicator))
            tap.cancelsTouchesInView = false
            indicatorView.addGestureRecognizer(tap)
            presentedView.addSubview(indicatorView)
            indicatorView.translatesAutoresizingMaskIntoConstraints = false
            indicatorView.widthAnchor.constraint(equalToConstant: 36).isActive = true
            indicatorView.heightAnchor.constraint(equalToConstant: 13).isActive = true
            indicatorView.centerXAnchor.constraint(equalTo: presentedView.centerXAnchor).isActive = true
            indicatorView.topAnchor.constraint(equalTo: presentedView.topAnchor, constant: 12).isActive = true
        }
        updateLayoutIndicator()
        indicatorView.style = .arrow
        gradeView.alpha = 0
        indicatorView.alpha = 0

        let initialFrame: CGRect = containerView.bounds

        containerView.insertSubview(snapshotViewContainer, belowSubview: presentedViewController.view)
        snapshotViewContainer.frame = initialFrame
        updateSnapshot()
        snapshotView?.layer.cornerRadius = 0
        backgroundView.backgroundColor = UIColor.black
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerView.insertSubview(backgroundView, belowSubview: snapshotViewContainer)
        NSLayoutConstraint.activate([
            self.backgroundView.topAnchor.constraint(equalTo: window.topAnchor),
            self.backgroundView.leftAnchor.constraint(equalTo: window.leftAnchor),
            self.backgroundView.rightAnchor.constraint(equalTo: window.rightAnchor),
            self.backgroundView.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])

        let transformForSnapshotView = CGAffineTransform.identity
            .translatedBy(x: 0, y: -snapshotViewContainer.frame.origin.y)
            .translatedBy(x: 0, y: topSpace)
            .translatedBy(x: 0, y: -snapshotViewContainer.frame.height / 2)
            .scaledBy(x: scaleForPresentingView, y: scaleForPresentingView)
            .translatedBy(x: 0, y: snapshotViewContainer.frame.height / 2)

        snapshotView?.addCornerRadiusAnimation(cornerRadius: cornerRadius, duration: 0.6)
        snapshotView?.layer.masksToBounds = true
        if #available(iOS 11.0, *) {
            presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        presentedView.layer.cornerRadius = cornerRadius
        presentedView.layer.masksToBounds = true

        presentedViewController.transitionCoordinator?.animate(
            alongsideTransition: { [weak self] _ in
                guard let `self` = self else { return }
                self.snapshotView?.transform = transformForSnapshotView
                self.gradeView.alpha = self.alpha
                self.indicatorView.alpha = 1
            }, completion: { _ in
                self.snapshotView?.transform = .identity
            }
        )

        if hapticMoments.contains(.willPresent) {
            feedbackGenerator.impactOccurred()
        }
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        guard let containerView = containerView else { return }
        updateSnapshot()
        presentedViewController.view.frame = frameOfPresentedViewInContainerView
        snapshotViewContainer.transform = .identity
        snapshotViewContainer.translatesAutoresizingMaskIntoConstraints = false
        snapshotViewContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
        updateSnapshotAspectRatio()

        if tapAroundToDismissEnabled {
            tap = UITapGestureRecognizer(target: self, action: #selector(tapArround))
            tap?.cancelsTouchesInView = false
            snapshotViewContainer.addGestureRecognizer(tap!)
        }

        if swipeToDismissEnabled {
            pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            pan!.delegate = self
            pan!.maximumNumberOfTouches = 1
            pan!.cancelsTouchesInView = false
            presentedViewController.view.addGestureRecognizer(pan!)
        }
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        guard let containerView = containerView else { return }
        startDismissing = true

        let initialFrame: CGRect = containerView.bounds

        let initialTransform = CGAffineTransform.identity
            .translatedBy(x: 0, y: -initialFrame.origin.y)
            .translatedBy(x: 0, y: topSpace)
            .translatedBy(x: 0, y: -initialFrame.height / 2)
            .scaledBy(x: scaleForPresentingView, y: scaleForPresentingView)
            .translatedBy(x: 0, y: initialFrame.height / 2)

        snapshotViewTopConstraint?.isActive = false
        snapshotViewWidthConstraint?.isActive = false
        snapshotViewAspectRatioConstraint?.isActive = false
        snapshotViewContainer.translatesAutoresizingMaskIntoConstraints = true
        snapshotViewContainer.frame = initialFrame
        snapshotViewContainer.transform = initialTransform

        let finalTransform: CGAffineTransform = .identity

        snapshotView?.addCornerRadiusAnimation(cornerRadius: 0, duration: 0.6)

        presentedViewController.transitionCoordinator?.animate(
            alongsideTransition: { [weak self] _ in
                guard let `self` = self else { return }
                self.snapshotView?.transform = .identity
                self.snapshotViewContainer.transform = finalTransform
                self.gradeView.alpha = 0
                self.indicatorView.alpha = 0
                if self.hapticMoments.contains(.willDismiss) {
                    self.feedbackGenerator.impactOccurred()
                }
            }
        )
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        guard let containerView = containerView else { return }

        backgroundView.removeFromSuperview()
        snapshotView?.removeFromSuperview()
        snapshotViewContainer.removeFromSuperview()
        indicatorView.removeFromSuperview()

        let offscreenFrame = CGRect(x: 0,
                                    y: containerView.bounds.height,
                                    width: containerView.bounds.width,
                                    height: containerView.bounds.height)
        presentedViewController.view.frame = offscreenFrame
        presentedViewController.view.transform = .identity
    }
}

extension CardPresentationController {
    @objc func tapIndicator() {
        dismiss(prepare: nil, completion: {
            self.cardDelegate?.didDismissCardByTap?()
        })
    }

    @objc func tapArround() {
        dismiss(prepare: nil, completion: {
            self.cardDelegate?.didDismissCardByTap?()
        })
    }

    @objc func tapCloseButton() {
        dismiss(prepare: nil, completion: {
            self.cardDelegate?.didDismissCardByTap?()
        })
    }

    public func dismiss(prepare _: (() -> Void)?, completion: (() -> Void)?) {
        let dismiss = {
            self.presentingViewController.view.endEditing(true)
            self.presentedViewController.view.endEditing(true)
            self.presentedViewController.dismiss(animated: true, completion: {
                completion?()
            })
        }
        dismiss()
    }

    @objc func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(pan), swipeToDismissEnabled else { return }

        switch gestureRecognizer.state {
        case .began:
            workGester = true

            presentingViewController.view.layer.removeAllAnimations()
            presentingViewController.view.endEditing(true)
            presentedViewController.view.endEditing(true)
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: containerView)
        case .changed:
            workGester = true
            let translation = gestureRecognizer.translation(in: presentedView)
            if translation.y > 0 {
                indicatorView.style = .line
            }
            if swipeToDismissEnabled {
                updatePresentedViewForTranslation(inVerticalDirection: translation.y)
            } else {
                gestureRecognizer.setTranslation(.zero, in: presentedView)
            }
        case .ended:
            workGester = false
            let translation = gestureRecognizer.translation(in: presentedView).y

            let toDefault = {
                self.indicatorView.style = .arrow
                UIView.animate(
                    withDuration: 0.6,
                    delay: 0,
                    usingSpringWithDamping: 1,
                    initialSpringVelocity: 1,
                    options: [.curveEaseOut, .allowUserInteraction],
                    animations: {
                        self.snapshotView?.transform = .identity
                        self.presentedView?.transform = .identity
                        self.gradeView.alpha = self.alpha
                        self.indicatorView.alpha = 1
                    }
                )
            }

            if translation >= translateForDismiss {
                dismiss(prepare: toDefault, completion: {
                    self.cardDelegate?.didDismissCardBySwipe?()
                })
            } else {
                toDefault()
            }
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let gester = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gester.velocity(in: presentedViewController.view)
            return abs(velocity.y) > abs(velocity.x)
        }
        return true
    }

    func scrollViewDidScroll(_ translation: CGFloat) {
        if !workGester {
            updatePresentedViewForTranslation(inVerticalDirection: translation)
        }
    }

    func updatePresentingController() {
        if startDismissing { return }
        updateSnapshot()
    }

    func setIndicator(style: CardIndicatorView.Style) {
        indicatorView.style = style
    }

    private func updatePresentedViewForTranslation(inVerticalDirection translation: CGFloat) {
        if startDismissing { return }

        let elasticThreshold: CGFloat = 120
        let translationFactor: CGFloat = 1 / 2

        if translation >= 0 {
            let translationForModal: CGFloat = {
                if translation >= elasticThreshold {
                    let frictionLength = translation - elasticThreshold
                    let frictionTranslation = 30 * atan(frictionLength / 120) + frictionLength / 10
                    return frictionTranslation + (elasticThreshold * translationFactor)
                } else {
                    return translation * translationFactor
                }
            }()

            presentedView?.transform = CGAffineTransform(translationX: 0, y: translationForModal)

            let scaleFactor = 1 + (translationForModal / 5000)
            snapshotView?.transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
            let gradeFactor = 1 + (translationForModal / 7000)
            gradeView.alpha = alpha - ((gradeFactor - 1) * 15)
        } else {
            presentedView?.transform = CGAffineTransform.identity
        }

        if swipeToDismissEnabled {
            let afterRealseDismissing = (translation >= translateForDismiss)
            if afterRealseDismissing != afterReleaseDismissing {
                afterReleaseDismissing = afterRealseDismissing
                if hapticMoments.contains(.willDismissIfRelease) {
                    feedbackGenerator.impactOccurred()
                }
            }
        }
    }
}

extension CardPresentationController {
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let containerView = containerView else { return }
        updateSnapshotAspectRatio()
        if presentedViewController.view.isDescendant(of: containerView) {
            presentedViewController.view.frame = frameOfPresentedViewInContainerView
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateLayoutIndicator()
        }, completion: { [weak self] _ in
            self?.updateSnapshotAspectRatio()
            self?.updateSnapshot()
        })
    }

    private func updateLayoutIndicator() {
        indicatorView.style = .line
        indicatorView.sizeToFit()
    }

    private func updateSnapshot() {
        guard let currentSnapshotView = presentingViewController.view.snapshotView(afterScreenUpdates: true) else { return }
        snapshotView?.removeFromSuperview()
        snapshotViewContainer.addSubview(currentSnapshotView)
        constraints(view: currentSnapshotView, to: snapshotViewContainer)
        snapshotView = currentSnapshotView
        snapshotView?.layer.cornerRadius = cornerRadius
        snapshotView?.layer.masksToBounds = true
        if #available(iOS 11.0, *) {
            snapshotView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        gradeView.removeFromSuperview()
        gradeView.backgroundColor = UIColor.black
        snapshotView!.addSubview(gradeView)
        constraints(view: gradeView, to: snapshotView!)
    }

    private func updateSnapshotAspectRatio() {
        guard let containerView = containerView, snapshotViewContainer.translatesAutoresizingMaskIntoConstraints == false else { return }

        snapshotViewTopConstraint?.isActive = false
        snapshotViewWidthConstraint?.isActive = false
        snapshotViewAspectRatioConstraint?.isActive = false

        let snapshotReferenceSize = presentingViewController.view.frame.size
        let aspectRatio = snapshotReferenceSize.width / snapshotReferenceSize.height

        snapshotViewTopConstraint = snapshotViewContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: topSpace)
        snapshotViewWidthConstraint = snapshotViewContainer.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: scaleForPresentingView)
        snapshotViewAspectRatioConstraint = snapshotViewContainer.widthAnchor.constraint(equalTo: snapshotViewContainer.heightAnchor, multiplier: aspectRatio)

        snapshotViewTopConstraint?.isActive = true
        snapshotViewWidthConstraint?.isActive = true
        snapshotViewAspectRatioConstraint?.isActive = true
    }

    private func constraints(view: UIView, to superView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: superView.topAnchor),
            view.leftAnchor.constraint(equalTo: superView.leftAnchor),
            view.rightAnchor.constraint(equalTo: superView.rightAnchor),
            view.bottomAnchor.constraint(equalTo: superView.bottomAnchor)
        ])
    }
}
