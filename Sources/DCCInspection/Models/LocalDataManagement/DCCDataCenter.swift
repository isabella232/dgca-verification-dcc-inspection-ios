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
    public static let revocationWorker: RevocationWorker = RevocationWorker()
    
    public static var downloadedDataHasExpired: Bool {
        return lastFetch.timeIntervalSinceNow < -SharedConstants.expiredDataInterval
    }
   
    public static var appWasRunWithOlderVersion: Bool {
        return localDataManager.localData.lastLaunchedAppVersion != appVersion
    }

    public static var lastFetch: Date {
        get {
            return localDataManager.localData.lastFetch
        }
        set {
            localDataManager.localData.lastFetch = newValue
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

    public class func prepareLocalData(completion: @escaping DataCompletionHandler) {
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            let shouldDownload = self.downloadedDataHasExpired || self.appWasRunWithOlderVersion
            if !shouldDownload {
                completion(result)
            } else {
                reloadStorageData { result in
                    localDataManager.loadLocallyStoredData { result in
                        CertLogicManager.shared.setRules(ruleList: rules)
                        completion(result)
                    }
                }
            }
        }
    }
    
    public static func reloadStorageData(completion: @escaping DataCompletionHandler) {
        let group = DispatchGroup()
        
        let center = NotificationCenter.default
        center.post(name: Notification.Name("StartLoadingNotificationName"), object: nil, userInfo: nil )
        
        group.enter()
        localDataManager.loadLocallyStoredData { result in
            CertLogicManager.shared.setRules(ruleList: rules)
            
            group.enter()
            GatewayConnection.updateLocalDataStorage { err in
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadCountryList { list, err in
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadValueSetsFromServer { list, err in
                group.leave()
            }
            
            group.enter()
            GatewayConnection.loadRulesFromServer { list, err  in
              CertLogicManager.shared.setRules(ruleList: rules)
              group.leave()
            }
            
            group.leave()
        }
        
        group.enter()
        revocationWorker.processReloadRevocations { error in
            if let err = error {
                if case let .failedValidation(status: status) = err, status == 404 {
                    group.enter()
                    revocationWorker.processReloadRevocations { err in
                        guard err == nil else {
                            print("Backend error!!")
                            return
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            localDataManager.localData.lastFetch = Date()
            center.post(name: Notification.Name("StopLoadingNotificationName"), object: nil, userInfo: nil )
            saveLocalData(completion: completion)
        }
    }
}