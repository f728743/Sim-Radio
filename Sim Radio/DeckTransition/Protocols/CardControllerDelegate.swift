//
//  CardControllerDelegate.swift
//  DeckTransition
//

import UIKit

@objc public protocol CardControllerDelegate: AnyObject {
    @objc optional func didDismissCardBySwipe()
    @objc optional func didDismissCardByTap()
}
