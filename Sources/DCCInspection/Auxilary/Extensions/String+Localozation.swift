//
//  localize.swift
//  
//
//  Created by Igor Khomiak on 11.04.2022.
//

import Foundation

func localize(_ string: String) -> String {
    return NSLocalizedString(string, tableName: nil, bundle: .module, comment: "No comment provided.")
}

func localize(_ string: String, with comment: String? = nil, or fallback: String? = nil) -> String {
    var text = NSLocalizedString(string, comment: comment ?? "No comment provided.")
    if text != string {
        return text
    }
    text = NSLocalizedString(string, bundle: .module, comment: comment ?? "No comment provided.")
    if text != string {
        return text
    }
    return fallback ?? string
}
