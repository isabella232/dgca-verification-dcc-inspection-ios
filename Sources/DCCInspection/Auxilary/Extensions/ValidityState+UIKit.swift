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
//  ValidityState+UIKit.swift
//  DGCAVerifier
//  
//  Created by Igor Khomiak on 02.11.2021.
//  
        

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import DGCCoreLibrary

public extension ValidityState {
    
    var technicalValidityString: String {
        switch self.technicalValidity {
        case .valid:
            return Icons.ok.rawValue
        case .invalid:
            return Icons.error.rawValue
        case .partlyValid:
            return Icons.limited.rawValue
        }
    }

    var issuerInvalidationString: String {
        switch self.issuerValidity {
        case .valid:
            return Icons.ok.rawValue
        case .invalid:
            return Icons.error.rawValue
        case .partlyValid:
            return Icons.limited.rawValue
        }
    }

    var destinationAcceptenceString: String {
        switch self.destinationValidity {
        case .valid:
            return Icons.ok.rawValue
        case .invalid:
            return Icons.error.rawValue
        case .partlyValid:
            return Icons.limited.rawValue
        }
    }
    
    var travalerAcceptenceString: String {
        switch self.travalerValidity {
        case .valid:
            return Icons.ok.rawValue
        case .invalid:
            return Icons.error.rawValue
        case .partlyValid:
            return Icons.limited.rawValue
        }
    }

#if os(iOS)
    var technicalValidityColor: UIColor {
        switch self.technicalValidity {
        case .valid:
            return UIColor.certificateValid
        case .invalid:
            return UIColor.certificateInvalid
        case .partlyValid:
            return UIColor.certificateRuleOpen
        }
    }

    var issuerInvalidationColor: UIColor {
        switch self.issuerValidity {
        case .valid:
            return UIColor.certificateValid
        case .invalid:
            return UIColor.certificateInvalid
        case .partlyValid:
            return UIColor.certificateRuleOpen
        }
    }

    var destinationAcceptenceColor: UIColor {
        switch self.destinationValidity {
        case .valid:
            return UIColor.certificateValid
        case .invalid:
            return UIColor.certificateInvalid
        case .partlyValid:
            return UIColor.certificateRuleOpen
        }
    }

    var travalerAcceptenceColor: UIColor {
        switch self.travalerValidity {
        case .valid:
            return UIColor.certificateValid
        case .invalid:
            return UIColor.certificateInvalid
        case .partlyValid:
            return UIColor.certificateRuleOpen
        }
    }
#else
    var technicalValidityColor: NSColor {
        switch self.technicalValidity {
        case .valid:
          return .green
        case .invalid:
          return .red
        case .ruleInvalid:
            return .yellow
        case .revoked:
            return .red
        }
    }

    var issuerInvalidationColor: NSColor {
        switch self.issuerValidity {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .ruleInvalid:
            return .yellow
        case .revoked:
            return .red
        }
    }
    
    var destinationAcceptenceColor: NSColor {
        switch self.destinationValidity {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .ruleInvalid:
            return .yellow
        case .revoked:
            return .red
        }
    }
    
    var travalerAcceptenceColor: NSColor {
        switch self.travalerValidity {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .ruleInvalid:
            return .yellow
        case .revoked:
            return .red
        }
    }
#endif
}
