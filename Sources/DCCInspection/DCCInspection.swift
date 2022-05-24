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
//  DCCInspection.swift
//  
//
//  Created by Igor Khomiak on 15.01.2022.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

import DGCCoreLibrary

public final class DCCInspection {
    
    #if os(iOS)
    static var cachedQrCodes = SyncDict<UIImage>()
    #else
    static var cachedQrCodes = SyncDict<NSImage>()
    #endif
    
    static var publicKeyEncoder: PublicKeyStorageDelegate?
    static var config = HCertConfig.default
        
    public init() { }

}

extension DCCInspection {
    public func makeCertificateViewerBuilder(_ hCert: HCert, validityState: ValidityState, for appType: AppType) -> DCCSectionBuilder {
        let builder = DCCSectionBuilder(with: hCert, validity: validityState, for: appType)
        return builder
    }
}

extension DCCInspection: CertificateValidating {
        
    public func validateCertificate(_ cert: CertificationProtocol) -> ValidityState? {
        guard let hCert = cert as? HCert else { return nil }
        
        let validator = DCCCertificateValidator(with: hCert)
        let validityState = validator.validateDCCCertificate()
        return validityState
    }
}

extension DCCInspection: DataLoadingProtocol {
    
    public var downloadedDataHasExpired: Bool {
        return DCCDataCenter.downloadedDataHasExpired
    }
    
    public var lastUpdate: Date {
        DCCDataCenter.lastFetch
    }

    public func prepareLocallyStoredData(appType: AppType, completion: @escaping DataCompletionHandler) {
        switch appType {
        case .verifier:
            DCCDataCenter.prepareVerifierLocalData(completion: completion)
            
        case .wallet:
            DCCDataCenter.prepareWalletLocalData(completion: completion)
        }
    }
    
    public func updateLocallyStoredData(appType: AppType, completion: @escaping DataCompletionHandler) {
        switch appType {
        case .verifier:
            DCCDataCenter.reloadVerifierStorageData(completion: completion)
        
        case .wallet:
            DCCDataCenter.reloadWalletStorageData(completion: completion)
        }
    }
}
