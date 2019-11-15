//
//  CardControllerDelegate.swift
//  DeckTransition
//

import UIKit

@objc public protocol CardControllerDelegate: class {
    @objc optional func didDismissCardBySwipe()

    @objc optional func didDismissCardByTap()
}
