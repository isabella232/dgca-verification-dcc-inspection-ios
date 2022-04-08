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
import DGCCoreLibrary


public extension VerificationResult {
  
    var validityResult: String {
        switch self {
        case .valid:
            return "Valid".localized
        case .invalid:
            return "Invalid".localized
        case .partlyValid:
            return "Limited validity".localized
    }
        
    var validityButtonTitle: String {
        switch self {
        case .valid:
            return "Done".localized
        case .invalid:
            return "Retry".localized
        case .partlyValid:
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
        case .partlyValid:
            return UIImage(named: "check", in: .module, compatibleWith: nil)!
        }
    }
        
    var revocationIcon: UIImage {
        return UIImage(named: "error", in: .module, compatibleWith: nil)!
    }

    var validityBackground: UIColor {
        switch self {
        case .valid:
            return UIColor.certificateGreen
        case .invalid:
            return UIColor.certificateRed
        case .partlyValid:
            return UIColor.certificateLimited
        }
    }
    
    var revocationBackground: UIColor {
        return UIColor.certificateRed
    }

#else
    var validityImage: NSImage {
        switch self {
        case .valid:
            return NSImage(named: "check")!
        case .invalid:
            return NSImage(named: "error")!
        case .partlyValid:
            return NSImage(named: "check")!
        }
    }
    var validityBackground: NSColor {
        switch self {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .partlyValid:
            return .yellow
        }
    }
#endif
}
