//
//  Time.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 20.12.2024.
//

import Foundation

public func delay(_ delay: Double, closure: @escaping () -> ()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}
