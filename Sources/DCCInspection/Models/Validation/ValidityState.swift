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
//  ValidityState.swift
//  DGCAVerifier
//  
//  Created by Igor Khomiak on 18.10.2021.
//  


import Foundation
import DGCCoreLibrary

public struct ValidityState: CertificateVerifying {
    
    public let technicalValidity: VerificationResult
    public let issuerValidity: VerificationResult
    public let destinationValidity: VerificationResult
    public let travalerValidity: VerificationResult
    public let allRulesValidity: VerificationResult
    public let validityFailures: [String]
    public var infoSection: InfoSection?
    public let isRevoked: Bool
    
    public var isVerificationFailed: Bool {
        return technicalValidity != .valid || issuerValidity != .valid ||
        destinationValidity != .valid || travalerValidity != .valid || isRevoked
    }
    
    public init(
        technicalValidity: VerificationResult,
        issuerValidity: VerificationResult,
        destinationValidity: VerificationResult,
        travalerValidity: VerificationResult,
        allRulesValidity: VerificationResult,
        validityFailures: [String],
        infoSection: InfoSection?,
        isRevoked: Bool
    ) {
        self.technicalValidity = technicalValidity
        self.issuerValidity = issuerValidity
        self.destinationValidity = destinationValidity
        self.travalerValidity = travalerValidity
        self.allRulesValidity = allRulesValidity
        self.validityFailures = validityFailures
        self.infoSection = infoSection
        self.isRevoked = isRevoked
    }
 }
