//
//  Date+Extensions.swift
//  SimRadio
//
//  Created by Alexey Vorobyov on 29.01.2025.
//

import Foundation

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    static var tomorrow: Date? { Date().dayAfter }

    var dayAfter: Date? {
        guard let noon else { return nil }
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)
    }

    var noon: Date? {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)
    }
}
