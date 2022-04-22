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
//  DCCCertificateValidator.swift
//  
//
//  Created by Igor Khomiak on 15.10.2021.
//

import Foundation
import DGCCoreLibrary
import CertLogic
import DGCBloomFilter
import DGCPartialVarHashFilter


public class DCCCertificateValidator {
    
    fileprivate let certificate: HCert
    fileprivate let revocationManager = RevocationCoreDataManager()
    
    public init(with cert: HCert) {
      self.certificate = cert
    }

    public func validateDCCCertificate() -> ValidityState {
        let failures = findValidityFailures()
        
        let technicalValidity: VerificationResult = failures.isEmpty ? .valid : .invalid
        let issuerValidity = validateCertLogicForIssuer()
        let destinationValidity = validateCertLogicForDestination()
        let travalerValidity = validateCertLogicForTraveller()
        let (infoRulesSection, allRulesValidity): (InfoSection?, VerificationResult)
        if technicalValidity == .valid {
            (infoRulesSection, allRulesValidity) = validateCertLogicForAllRules()
        } else {
            (infoRulesSection, allRulesValidity) = (nil, .invalid)
        }
        var isRevoked: Bool = false
        
        if technicalValidity != .invalid {
            isRevoked = self.validateRevocation()
        }
        
        let validityState = ValidityState(
            technicalValidity: technicalValidity,
            issuerValidity: issuerValidity,
            destinationValidity: destinationValidity,
            travalerValidity: travalerValidity,
            allRulesValidity: allRulesValidity,
            validityFailures: failures,
            infoSection: infoRulesSection,
            isRevoked: isRevoked)
        return validityState
    }
  
    private func findValidityFailures() -> [String] {
        var failures = [String]()
        if !certificate.cryptographicallyValid {
          failures.append(localize("No entries in the certificate."))
        }
        if certificate.exp < HCert.clock {
          failures.append(localize("Certificate past expiration date."))
        }
        if certificate.iat > HCert.clock {
          failures.append(localize("Certificate issuance date is in the future."))
        }
        if certificate.statement == nil {
          failures.append(localize("No entries in the certificate."))
          return failures
        }
        failures.append(contentsOf: certificate.statement.validityFailures)
        return failures
    }

    // MARK: - private validation methods
    private func validateCertLogicForAllRules() -> (InfoSection?, VerificationResult) {
        var validity: VerificationResult = .valid
        let certType = certificationType(for: certificate.certificateType)
        var infoSection: InfoSection?
      
        if let countryCode = certificate.ruleCountryCode {
            let valueSets = DCCDataCenter.localDataManager.getValueSetsForExternalParameters()
            let filterParameter = FilterParameter(validationClock: Date(),
                countryCode: countryCode,
                certificationType: certType)
            let externalParameters = ExternalParameter(validationClock: Date(),
                 valueSets: valueSets,
                 exp: certificate.exp,
                 iat: certificate.iat,
                 issuerCountryCode: certificate.issCode,
                 kid: certificate.kidStr)
            let result = CertLogicManager.shared.validate(filter: filterParameter,
                external: externalParameters, payload: certificate.body.description)
            let failsAndOpen = result.filter { $0.result != .passed }
            
            if failsAndOpen.count > 0 {
                validity = .partlyValid
                infoSection = InfoSection(header: localize("Possible limitation"), content: localize("Country rules validation failed"))
                var listOfRulesSection: [InfoSection] = []
                result.sorted(by: { $0.result.rawValue < $1.result.rawValue }).forEach { validationResult in
                  if let error = validationResult.validationErrors?.first {
                      switch validationResult.result {
                      case .fail:
                          listOfRulesSection.append(InfoSection(header: localize("Cannot validate the certificate"),
                            content: error.localizedDescription,
                            countryName: certificate.ruleCountryCode,
                            ruleValidationResult: .invalid))
                      case .open:
                          listOfRulesSection.append(InfoSection(header: localize("Cannot validate the certificate"),
                            content: error.localizedDescription,
                            countryName: certificate.ruleCountryCode,
                            ruleValidationResult: .partlyValid))
                      case .passed:
                          listOfRulesSection.append(InfoSection(header: localize("Cannot validate the certificate"),
                            content: error.localizedDescription,
                            countryName: certificate.ruleCountryCode,
                            ruleValidationResult: .valid))
                      }
                      
                    } else {
                        let preferredLanguage = Locale.preferredLanguages[0] as String
                        let arr = preferredLanguage.components(separatedBy: "-")
                        let deviceLanguage = (arr.first ?? "EN")
                        var errorString = ""
                        if let error = validationResult.rule?.getLocalizedErrorString(locale: deviceLanguage) {
                          errorString = error
                        }
                        var detailsError = ""
                        if let rule = validationResult.rule {
                          let dict = CertLogicManager.shared.getRuleDetailsError(rule: rule, filter: filterParameter)
                          dict.keys.forEach({ detailsError += $0 + ": " + (dict[$0] ?? "") + " " })
                        }
                        switch validationResult.result {
                        case .fail:
                          listOfRulesSection.append(InfoSection(header: errorString,
                              content: detailsError,
                              countryName: certificate.ruleCountryCode,
                              ruleValidationResult: .invalid)
                          )
                        case .open:
                          listOfRulesSection.append(InfoSection(header: errorString,
                              content: detailsError,
                              countryName: certificate.ruleCountryCode,
                              ruleValidationResult: .partlyValid)
                          )
                        case .passed:
                          listOfRulesSection.append(InfoSection(header: errorString,
                              content: detailsError,
                              countryName: certificate.ruleCountryCode,
                              ruleValidationResult: .valid))
                        }
                    }
                }
                infoSection?.sectionItems = listOfRulesSection
            }
        }
        return (infoSection, validity)
    }

    private func validateCertLogicForIssuer() -> VerificationResult {
        let certType = certificationType(for: certificate.certificateType)
        if let countryCode = certificate.ruleCountryCode {
            let valueSets = DCCDataCenter.localDataManager.getValueSetsForExternalParameters()
            let filterParameter = FilterParameter(validationClock: Date(), countryCode: countryCode, certificationType: certType)
            let externalParameters = ExternalParameter(validationClock: Date(),
               valueSets: valueSets,
               exp: certificate.exp,
               iat: certificate.iat,
               issuerCountryCode: certificate.issCode,
               kid: certificate.kidStr)
            let result = CertLogicManager.shared.validateIssuer(filter: filterParameter,
                external: externalParameters, payload: certificate.body.description)
            let fails = result.filter { $0.result == .fail }
            if !fails.isEmpty {
                return .invalid
            }
            let open = result.filter { $0.result == .open }
            if !open.isEmpty {
                return .partlyValid
            }
        }
        return .valid
    }

    private func validateCertLogicForDestination() -> VerificationResult {
        let certType = certificationType(for: certificate.certificateType)
        if let countryCode = certificate.ruleCountryCode {
            let valueSets = DCCDataCenter.localDataManager.getValueSetsForExternalParameters()
              
            let filterParameter = FilterParameter(validationClock: Date(), countryCode: countryCode, certificationType: certType)
              
            let externalParameters = ExternalParameter(validationClock: Date(),
              valueSets: valueSets,
              exp: certificate.exp,
              iat: certificate.iat,
              issuerCountryCode: certificate.issCode,
              kid: certificate.kidStr)
            let result = CertLogicManager.shared.validateDestination(filter: filterParameter, external: externalParameters,
                payload: certificate.body.description)
            let fails = result.filter { $0.result == .fail }
            if !fails.isEmpty {
                return .invalid
            }
            let open = result.filter { $0.result == .open }
            if !open.isEmpty {
                return .partlyValid
            }
        }
        return .valid
    }
    
    private func validateCertLogicForTraveller() -> VerificationResult {
        let certType = certificationType(for: certificate.certificateType)
        if let countryCode = certificate.ruleCountryCode {
            let valueSets = DCCDataCenter.localDataManager.getValueSetsForExternalParameters()
            let filterParameter = FilterParameter(validationClock: Date(),
                countryCode: countryCode,
                certificationType: certType)
            let externalParameters = ExternalParameter(validationClock: Date(),
               valueSets: valueSets,
               exp: certificate.exp,
               iat: certificate.iat,
               issuerCountryCode: certificate.issCode,
               kid: certificate.kidStr)
            let result = CertLogicManager.shared.validateTraveller(filter: filterParameter,
                external: externalParameters, payload: certificate.body.description)
            
            let fails = result.filter { $0.result == .fail }
            if !fails.isEmpty {
                return .invalid
            }
            let open = result.filter { $0.result == .open }
            if !open.isEmpty {
                return .partlyValid
            }
        }
        return .valid
    }

    private func certificationType(for type: HCertType) -> CertificateType {
        switch type {
        case .recovery:
            return .recovery
        case .test:
            return .test
        case .vaccine:
            return .vaccination
        case .unknown:
            return .general
        }
    }
}


extension DCCCertificateValidator {
    
    func validateRevocation() -> Bool {
        let certKID = certificate.kidStr
        
        if let revocation = revocationManager.loadRevocation(kid: certKID),
           let revocMode = RevocationMode(rawValue: revocation.value(forKey: "mode") as! String),
            let hashTypes = revocation.value(forKey: "hashTypes") as? String {
            let arrayHashTypes = hashTypes.split(separator: ",")
            
            if arrayHashTypes.contains("SIGNATURE"), let hashData = certificate.signatureHash {
                let lookup: CertLookUp = certificate.lookUp(mode: revocMode, hash: hashData)
                let result = searchInDatabase(lookUp: lookup, hash: hashData)
                if result == true {
                    return true
                }
            }
            
            if arrayHashTypes.contains("UCI"), let hashData = certificate.uvciHash {
                let lookup: CertLookUp = certificate.lookUp(mode: revocMode, hash: hashData)
                let result = searchInDatabase(lookUp: lookup, hash: hashData)
                if result == true {
                    return true
                }
            }
            
            if arrayHashTypes.contains("COUNTRYCODEUCI"), let hashData = certificate.countryCodeUvciHash {
                let lookup: CertLookUp = certificate.lookUp(mode: revocMode, hash: hashData)
                let result = searchInDatabase(lookUp: lookup, hash: hashData)
                if result == true {
                    return true
                }
            }
        }
        return false
    }
    
    private func searchInDatabase(lookUp: CertLookUp, hash: Data) -> Bool {
        let slices = revocationManager.loadSlices(kid: lookUp.kid, x: lookUp.x, y: lookUp.y, section: lookUp.section)
        for slice in slices ?? [] {
            guard let sliceData = slice.value(forKey: "hashData") as? Data,
                let sliceType = slice.value(forKey: "type") as? String else { continue }
            
            if sliceType.lowercased().contains("bloom") {
                let filter = BloomFilter(data: sliceData)
                let result = filter.mightContain(element: hash)
                if result {
                    return true
                }
            } else if sliceType.lowercased().contains("hash") {
                let filter = VariableHashFilter(data: sliceData)
                if let result = filter?.mightContain(element: hash), result == true {
                    return true
                }
            } else {
                DGCLogger.logInfo("Revocation Error: Unsupported type of hash")
            }
        }
        return false
    }
}
