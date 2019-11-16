//
//  String+Extension.swift
//  Sim Radio
//

import Foundation

extension String {
    func appendingPathComponent(_ path: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(path)
    }
}
