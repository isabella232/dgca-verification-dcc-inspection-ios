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
//  LocalDataManager.swift
//  DGCAVerifier
//  
//  Created by Yannick Spreen on 4/25/21.
//  

import Foundation
import DGCCoreLibrary
import SwiftyJSON
import CertLogic

public class LocalDataManager {
    lazy var storage = SecureStorage<LocalData>(fileName: SharedConstants.dataStorageName)
    var localData = LocalData()
    
    // MARK: - Public Keys
    public func add(encodedPublicKey: String) {
        let kid = KID.from(encodedPublicKey)
        let kidStr = KID.string(from: kid)
        
        let list = localData.encodedPublicKeys[kidStr] ?? []
        if !list.contains(encodedPublicKey) {
            localData.encodedPublicKeys[kidStr] = list + [encodedPublicKey]
        }
    }
    
    // MARK: - Certificates
    public func add(_ cert: HCert, with tan: String?, completion: @escaping DataCompletionHandler) {
        localData.certStrings.append(DatedCertString(date: Date(), certString: cert.fullPayloadString, storedTAN: tan, isRevoked: cert.isRevoked))
        storage.save(localData, completion: completion)
    }
    
    public func remove(withDate date: Date, completion: @escaping DataCompletionHandler) {
      if let ind = localData.certStrings.firstIndex(where: { $0.date == date }) {
          localData.certStrings.remove(at: ind)
          storage.save(localData, completion: completion)
      }
    }

    // MARK: - Countries
    public func add(country: CountryModel) {
        if !localData.countryCodes.contains(where: { $0.code == country.code }) {
            localData.countryCodes.append(country)
        }
    }
    
    public func update(country: CountryModel) {
        guard let countryFromDB = localData.countryCodes.filter({ $0.code == country.code }).first else { return }
        countryFromDB.debugModeEnabled = country.debugModeEnabled
    }
    
    // MARK: - ValueSets
    public func add(valueSet: ValueSet) {
        if !localData.valueSets.contains(where: { $0.valueSetId == valueSet.valueSetId }) {
            localData.valueSets.append(valueSet)
        }
    }
    
    public func deleteValueSetWithHash(hash: String) {
        localData.valueSets = localData.valueSets.filter { $0.hash != hash }
    }
    
    public func isValueSetExistWithHash(hash: String) -> Bool {
        return localData.valueSets.contains(where: { $0.hash == hash })
    }
    
    public func getValueSetsForExternalParameters() -> Dictionary<String, [String]> {
        var returnValue = Dictionary<String, [String]>()
        localData.valueSets.forEach { valueSet in
            let keys = Array(valueSet.valueSetValues.keys)
            returnValue[valueSet.valueSetId] = keys
        }
        return returnValue
    }

    // MARK: - Rules
    public func add(rule: Rule) {
        if !localData.rules.contains(where: { $0.identifier == rule.identifier && $0.version == rule.version }) {
            localData.rules.append(rule)
        }
    }
    
    public func deleteRuleWithHash(hash: String) {
        localData.rules = localData.rules.filter { $0.hash != hash }
    }
      
    public func isRuleExistWithHash(hash: String) -> Bool {
        return localData.rules.contains(where: { $0.hash == hash })
    }

    // MARK: - Config
    public func merge(other: JSON) {
        localData.config.merge(other: other)
    }
    
    public var versionedConfig: JSON {
        if localData.config["versions"][DCCDataCenter.appVersion].exists() {
            return localData.config["versions"][DCCDataCenter.appVersion]
        } else {
            return localData.config["versions"]["default"]
        }
    }

    // MARK: - Services
    public func save(completion: @escaping DataCompletionHandler) {
        storage.save(localData, completion: completion)
    }

    public func loadLocallyStoredData(completion: @escaping DataCompletionHandler) {
        storage.loadStoredData(fallback: localData) { [unowned self] data in
            guard let loadedData = data else {
                completion(.failure(DataOperationError.noInputData))
                return
            }
            let format = "%d pub keys loaded."
            DGCLogger.logInfo(String(format: format, loadedData.encodedPublicKeys.count))
            if loadedData.lastLaunchedAppVersion != DCCDataCenter.appVersion {
                loadedData.config = self.localData.config
                loadedData.lastLaunchedAppVersion = DCCDataCenter.appVersion
            }
            DCCInspection.publicKeyEncoder = LocalDataKeyEncoder()
            self.localData = loadedData
            self.save(completion: completion)
        }
    }
}

public class LocalDataKeyEncoder: PublicKeyStorageDelegate {
    public func getEncodedPublicKeys(for kidStr: String) -> [String] {
        DCCDataCenter.localDataManager.localData.encodedPublicKeys[kidStr] ?? []
    }
}
