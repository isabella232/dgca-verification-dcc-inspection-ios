//
/*-
 * ---license-start
 * eu-digital-green-certificates / dgca-verifier-app-ios
 * ---
 * Copyright (C) 2021 T-Systems International GmbH and all other contributors
 * ---
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ---license-end
 */
//  
//  HCertValidity+UIKit.swift
//  DGCAVerifier
//  
//  Created by Igor Khomiak on 29.10.2021.
//  
        

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import CoreLibrary

public extension HCertValidity {
  
    var validityResult: String {
        switch self {
        case .valid:
            return "Valid".localized
        case .invalid:
            return "Invalid".localized
        case .ruleInvalid:
            return "Limited validity".localized
        case .revoked:
            return "Revoked".localized
        }
    }
        
    var validityButtonTitle: String {
        switch self {
        case .valid:
            return "Done".localized
        case .invalid:
            return "Retry".localized
        case .ruleInvalid:
            return "Retry".localized
        case .revoked:
            return "Retry".localized
        }
    }

#if os(iOS)
    var validityImage: UIImage {
        switch self {
        case .valid:
            return UIImage(named: "check", in: .module, compatibleWith: nil)!
        case .invalid:
            return UIImage(named: "error", in: .module, compatibleWith: nil)!
        case .ruleInvalid:
            return UIImage(named: "check", in: .module, compatibleWith: nil)!
        case .revoked:
            return UIImage(named: "error", in: .module, compatibleWith: nil)!
        }
    }

    var validityBackground: UIColor {
        switch self {
        case .valid:
            return UIColor.certificateGreen
        case .invalid:
            return UIColor.certificateRed
        case .ruleInvalid:
            return UIColor.certificateLimited
        case .revoked:
            return UIColor.certificateRed
        }
    }
#else
    var validityImage: NSImage {
        switch self {
        case .valid:
            return NSImage(named: "check")!
        case .invalid:
            return NSImage(named: "error")!
        case .ruleInvalid:
            return NSImage(named: "check")!
        case .revocated:
            return NSImage(named: "error")!
        }
    }
    var validityBackground: NSColor {
        switch self {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .ruleInvalid:
            return .yellow
        case .revocated:
            return .red
        }
    }
#endif
}
