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
//  UIColor+Verifier.swift
//  DGCAVerifier
//  
//  Created by Yannick Spreen on 4/29/21.
//  

#if os(iOS)
import UIKit

extension UIColor {
    static var certificateRed: UIColor {
        UIColor(named: "certificateRed", in: .module, compatibleWith: nil)!
    }
    static var certificateGreen: UIColor {
        UIColor(named: "certificateGreen", in: .module, compatibleWith: nil)!
    }
    static var verifierBlue: UIColor {
        UIColor(named: "verifierBlue", in: .module, compatibleWith: nil)!
    }
    static var charcoalGrey: UIColor {
        UIColor(named: "charcoalGrey", in: .module, compatibleWith: nil)!
    }
    static var certificateLimited: UIColor {
        UIColor(named: "certificateLimited", in: .module, compatibleWith: nil)!
    }
    static var certificateValid: UIColor {
        UIColor(named: "certificateValid", in: .module, compatibleWith: nil)!
    }
    static var certificateInvalid: UIColor! {
        UIColor(named: "certificateInvalid", in: .module, compatibleWith: nil)!
    }
    static var certificateRuleOpen: UIColor {
        UIColor(named: "certificateRuleOpen", in: .module, compatibleWith: nil)!
    }
}

#endif
