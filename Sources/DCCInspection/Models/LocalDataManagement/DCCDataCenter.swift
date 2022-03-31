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
//  DCCDataCenter.swift
//  DGCAVerifier
//  
//  Created by Igor Khomiak on 03.11.2021.
//  
        

import Foundation
import DGCCoreLibrary
import CertLogic

public class DCCDataCenter {
    public static var appVersion: String {
        let versionValue = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?.?.?"
        let buildNumValue = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?.?.?"
        return "\(versionValue)(\(buildNumValue))"
    }
    
    public static let localDataManager: LocalDataManager = LocalDataManager()
    public static let localImageManager: LocalImageManager = LocalImageManager()
    static let revocationWorker: RevocationWorker = RevocationWorker()
    
    public static var downloadedDataHasExpired: Bool {
        return lastFetch.timeIntervalSinceNow < -SharedConstants.expiredDataInterval
    }
    
    public static var appWasRunWithOlderVersion: Bool {
        return localDataManager.localData.lastLaunchedAppVersion != appVersion
    }
    
    public static var lastLaunchedAppVersion: String {
        get {
            return localDataManager.localData.lastLaunchedAppVersion
        }
        set {
            localDataManager.localData.lastLaunchedAppVersion = newValue
        }
    }
    
    public static var lastFetch: Date {
        get {
            return localDataManager.localData.lastFetch
        }
        set {
            localDataManager.localData.lastFetch = newValue
        }
    }
    
    public static var certStrings: [DatedCertString] {
        get {
          return localDataManager.localData.certStrings
        }
        set {
          localDataManager.localData.certStrings = newValue
        }
    }
    
    public static var resumeToken: String {
        get {
            return localDataManager.localData.resumeToken
        }
        set {
            localDataManager.localData.resumeToken = newValue
        }
    }
    
    public static var publicKeys: [String: [String]] {
        get {
            return localDataManager.localData.encodedPublicKeys
        }
        set {
            localDataManager.localData.encodedPublicKeys = newValue
        }
    }
    
    public static var countryCodes: [CountryModel] {
        get {
            return localDataManager.localData.countryCodes
        }
        set {
            localDataManager.localData.countryCodes = newValue
        }
    }
    
    public static var rules: [Rule] {
        get {
          return localDataManager.localData.rules
        }
        set {
            localDataManager.localData.rules = newValue
        }
    }
    
    public static var valueSets: [ValueSet] {
        get {
          return localDataManager.localData.valueSets
        }
        set {
            localDataManager.localData.valueSets = newValue
        }
    }
    
    public static var images: [SavedImage] {
        get {
            return localImageManager.localData.images
        }
        set {
            localImageManager.localData.images = newValue
        }
    }
    
    public static var pdfs: [SavedPDF] {
        get {
            return localImageManager.localData.pdfs
        }
        set {
            localImageManager.localData.pdfs = newValue
        }
    }

    public static func saveLocalData(completion: @escaping DataCompletionHandler) {
        localDataManager.save(completion: completion)
    }
    
    public static func addValueSets(_ list: [ValueSet]) {
        list.forEach { localDataManager.add(valueSet: $0) }
    }

    public static func addRules(_ list: [Rule]) {
        list.forEach { localDataManager.add(rule: $0) }
    }

    public static func addCountries(_ list: [CountryModel]) {
        localDataManager.localData.countryCodes.removeAll()
        list.forEach { localDataManager.add(country: $0) }
    }

    static func prepareVerifierLocalData(completion: @escaping DataCompletionHandler) {
        let group = DispatchGroup()
        group.enter()
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            group.leave()
        }
        group.wait()
        
        let areNotDownloadedData = countryCodes.isEmpty || rules.isEmpty || valueSets.isEmpty
        let shouldReloadData = self.downloadedDataHasExpired || self.appWasRunWithOlderVersion
        
        if areNotDownloadedData || shouldReloadData {
            reloadVerifierStorageData { result in
                if case .failure(_) = result {
                    if areNotDownloadedData {
                        completion(.noData)
                    } else {
                        completion(result)
                    }
                } else {
                    localDataManager.loadLocallyStoredData { result in
                        let areNotDownloadedData = countryCodes.isEmpty || rules.isEmpty || valueSets.isEmpty
                        if areNotDownloadedData {
                            completion(.noData)
                        }
                        CertLogicManager.shared.setRules(ruleList: rules)
                        completion(.success)
                    }
                }
            }
            
        } else {
            localDataManager.loadLocallyStoredData { result in
                CertLogicManager.shared.setRules(ruleList: rules)
                completion(result)
            }
        }
    }

    static func reloadVerifierStorageData(completion: @escaping DataCompletionHandler) {
        let group = DispatchGroup()
                
        var errorOccured = false
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            
            group.enter()
            GatewayConnection.updateLocalDataStorage { err in
                if err != nil { errorOccured = true }
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadCountryList { list, err in
                if err != nil { errorOccured = true }
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadValueSetsFromServer { list, err in
                if err != nil { errorOccured = true }
                group.leave()
             }
            
            group.enter()
            GatewayConnection.loadRulesFromServer { list, err  in
                if err != nil { errorOccured = true }
                group.leave()
                CertLogicManager.shared.setRules(ruleList: rules)
            }
        }
        group.wait()
        
        group.enter()
        revocationWorker.processReloadRevocations { error in
            if let err = error {
                if case let .failedValidation(status: status) = err, status == 404 {
                    group.enter()
                    revocationWorker.processReloadRevocations { err in
                        if err != nil { errorOccured = true }
                        group.leave()
                    }
                }
                errorOccured = true
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if errorOccured == true {
                DispatchQueue.main.async {
                    completion(.failure(.noInputData))
                }
            } else {
                lastFetch = Date()
                lastLaunchedAppVersion = Self.appVersion
                saveLocalData(completion: completion)
            }
        }
    }
}

extension DCCDataCenter {
    static func prepareWalletLocalData(completion: @escaping DataCompletionHandler) {
        let group = DispatchGroup()
        var requestResult: DataOperationResult = .success
        
        group.enter()
        initializeWalletStorageData { result in
            requestResult = result
            CertLogicManager.shared.setRules(ruleList: rules)
            
            let shouldDownload = self.downloadedDataHasExpired || self.appWasRunWithOlderVersion
            if !shouldDownload {
                group.notify(queue: .main) {
                    completion(.success)
                }
                
            } else {
                group.enter()
                reloadWalletStorageData { result in
                    requestResult = result
                    group.enter()
                    localDataManager.loadLocallyStoredData { result in
                        requestResult = result
                        CertLogicManager.shared.setRules(ruleList: rules)
                        group.leave()
                    }
                    
                    group.leave()
                }
            }
            
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(requestResult)
        }
    }
    
    static func initializeWalletStorageData(completion: @escaping DataCompletionHandler) {
        let group = DispatchGroup()
        
        group.enter()
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            group.leave()
        }
        
        group.enter()
        localImageManager.loadLocallyStoredData { result in
          group.leave()
        }
        
        group.enter()
        GatewayConnection.lookup(certStrings: certStrings) { success, _, err in
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(.success)
        }
    }
    
    static func reloadWalletStorageData(completion: @escaping DataCompletionHandler) {
        var errorOccured = false
        
        let group = DispatchGroup()
        group.enter()
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            
            group.enter()
            GatewayConnection.updateLocalDataStorage { err in
                if err != nil { errorOccured = true }
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadCountryList { list, err in
                if err != nil { errorOccured = true }
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadValueSetsFromServer { list, err in
                if err != nil { errorOccured = true }
                group.leave()
            }
            
            group.enter()
            GatewayConnection.lookup(certStrings: certStrings) { success, _, err in
                if err != nil { errorOccured = true }
              group.leave()
            }
            
            group.enter()
            GatewayConnection.loadRulesFromServer { list, err  in
                if err != nil { errorOccured = true }
              CertLogicManager.shared.setRules(ruleList: rules)
              group.leave()
            }

            group.leave()
        }
    
        group.notify(queue: .main) {
            if errorOccured == true {
                DispatchQueue.main.async {
                    completion(.failure(.noInputData))
                }
            } else {
                lastFetch = Date()
                lastLaunchedAppVersion = Self.appVersion
                saveLocalData(completion: completion)
            }
        }
    }
}
