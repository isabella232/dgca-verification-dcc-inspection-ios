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
//  DatedCertString.swift
//  
//
//  Created by Igor Khomiak on 30.03.2022.
//

import Foundation

public class DatedCertString: Codable {
    public var isSelected: Bool = false
    public let date: Date
    public let certString: String
    public let storedTAN: String?
    public var cert: HCert? {
        return try? HCert(payload: certString, ruleCountryCode: nil)
    }
    
    public init(date: Date, certString: String, storedTAN: String?, isRevoked: Bool?) {
        self.date = date
        if isRevoked != nil && isRevoked == true {
            self.certString = "x" + certString
        } else {
            self.certString = certString
        }
        self.storedTAN = storedTAN
    }
}
