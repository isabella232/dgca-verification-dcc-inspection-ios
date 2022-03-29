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
//  GatewayConnection.swift
//  DGCAVerifier
//  
//  Created by Yannick Spreen on 4/24/21.
//  

import Foundation
import Alamofire
import DGCCoreLibrary
import SwiftyJSON
import CertLogic

enum GatewayError: Error {
  case insufficientData
  case encodingError
  case signingError
  case updatingError
  case incorrectDataResponse
  case connection(error: Error)
  case local(description: String)
  case parsingError
  case privateKeyError
  case tokenError
}

typealias GatewayCompletion = (GatewayError?) -> Void
typealias CertUpdateCompletion = (String?, String?, GatewayError?) -> Void

typealias CertStatusCompletion = ([String]?, GatewayError?) -> Void
typealias ValueSetsCompletion = ([ValueSet]?, GatewayError?) -> Void
typealias ValueSetCompletionHandler = (ValueSet?, GatewayError?) -> Void
typealias RulesCompletion = ([Rule]?, GatewayError?) -> Void
typealias RuleCompletionHandler = (Rule?, GatewayError?) -> Void
typealias CountryCompletionHandler = ([CountryModel]?, GatewayError?) -> Void

class GatewayConnection: ContextConnection {
    static func certUpdate(resume resumeToken: String? = nil, completion: @escaping CertUpdateCompletion) {
        var headers = [String: String]()
        if let token = resumeToken {
            headers["x-resume-token"] = token
        }
        request( ["endpoints", "update"], method: .get, encoding: URLEncoding(), headers: .init(headers)).response {
            if let status = $0.response?.statusCode, status == 204 {
                completion(nil, nil, nil)
                return
            }

            guard case let .success(result) = $0.result,
                  let response = result,
                  let responseStr = String(data: response, encoding: .utf8),
                  let headers = $0.response?.headers,
                  let responseKid = headers["x-kid"],
                  let newResumeToken = headers["x-resume-token"]
            else {
                completion(nil, nil, GatewayError.parsingError)
                return
            }

            let kid = KID.from(responseStr)
            let kidStr = KID.string(from: kid)
            if kidStr != responseKid {
                completion(nil, newResumeToken, nil)
            } else {
                completion(responseStr, newResumeToken, nil)
            }
        }
    }
    
    static func certStatus(resume resumeToken: String? = nil, completion: @escaping CertStatusCompletion) {
        request(["endpoints", "status"]).response {
            guard case let .success(result) = $0.result,
                let response = result,
                let responseStr = String(data: response, encoding: .utf8),
                let json = JSON(parseJSON: responseStr).array
            else {
                completion(nil, GatewayError.parsingError)
                return
            }
            let kids = json.compactMap { $0.string }
            completion(kids, nil)
        }
    }
    
    static func updateLocalDataStorage(completion: @escaping GatewayCompletion) {
        certUpdate(resume: DCCDataCenter.resumeToken) { encodedCert, token, err in
            guard err == nil else {
                completion(GatewayError.connection(error: err!))
                return
            }
            
            if let encodedCert = encodedCert {
                DCCDataCenter.localDataManager.add(encodedPublicKey: encodedCert)
                DCCDataCenter.resumeToken = token ?? ""
                DCCDataCenter.lastFetch = Date()
                updateLocalDataStorage(completion: completion)
            } else {
                getStatus { err in
                    completion(err)
                }
            }
        }
    }

    private static func getStatus(completion: @escaping GatewayCompletion) {
        certStatus { validKids, err in
            guard err == nil else {
                completion(GatewayError.connection(error: err!))
                return
            }
            
            let invalid = DCCDataCenter.publicKeys.keys.filter { !((validKids ?? []).contains($0)) }
            for key in invalid {
                DCCDataCenter.publicKeys.removeValue(forKey: key)
            }
            DCCDataCenter.lastFetch = Date()
            DCCDataCenter.saveLocalData { result in
                completion(nil)
            }
        }
    }

    static func fetchContext(completion: @escaping (() -> Void)) {
        request( ["context"] ).response {
            guard let data = $0.data, let string = String(data: data, encoding: .utf8) else {
                completion()
                return
            }
            let json = JSON(parseJSONC: string)
            DCCDataCenter.localDataManager.merge(other: json)
            DCCDataCenter.lastFetch = Date()
            DCCDataCenter.saveLocalData { result in
                if DCCDataCenter.localDataManager.versionedConfig["outdated"].bool == true {
//                    DispatchQueue.main.async {
//                      (UIApplication.shared.windows.first?.rootViewController as? UINavigationController)?
//                          .popToRootViewController(animated: false)
//                    }
                }
                completion()
            }
        }
    }

    static var config: JSON {
        return DCCDataCenter.localDataManager.versionedConfig
    }
}

// MARK: Country, Rules, Valuesets extension
extension GatewayConnection {
    // MARK: Country List
    static func getListOfCountry(completion: @escaping CountryCompletionHandler) {
        request(["endpoints", "countryList"], method: .get).response {
            guard case let .success(result) = $0.result, let response = result,
                let responseStr = String(data: response, encoding: .utf8), let json = JSON(parseJSON: responseStr).array
            else {
                completion(nil, GatewayError.parsingError)
                return
            }
            let codes = json.compactMap { $0.string }
            var countryList: [CountryModel] = []
            codes.forEach { countryList.append(CountryModel(code: $0)) }
            completion(countryList, nil)
        }
    }
    
    static func loadCountryList(completion: @escaping CountryCompletionHandler) {
       if !DCCDataCenter.countryCodes.isEmpty {
        completion(DCCDataCenter.countryCodes.sorted(by: { $0.name < $1.name }), nil)
       } else {
           getListOfCountry { countryList, err in
               guard err == nil else {
                   completion(nil, GatewayError.connection(error: err!))
                   return
               }
               if let countryList = countryList {
                   DCCDataCenter.addCountries(countryList)
               }
               completion(DCCDataCenter.countryCodes.sorted(by: { $0.name < $1.name }), nil)
            }
        }
    }
    
    // MARK: Rules
    static private func getListOfRules(completion: @escaping RulesCompletion) {
        request(["endpoints", "rules"], method: .get).response {
            guard case let .success(result) = $0.result, let response = result, let responseStr = String(data: response, encoding: .utf8)
            else {
                completion(nil, GatewayError.parsingError)
                return
            }
            
            let ruleHashes: [RuleHash] = CertLogicEngine.getItems(from: responseStr)
            // Remove old hashes
            DCCDataCenter.rules = DCCDataCenter.rules.filter { rule in
                return !ruleHashes.contains(where: { $0.hash == rule.hash })
            }
            // Downloading new hashes
            let rulesItems = SyncArray<Rule>()
            let downloadingGroup = DispatchGroup()
            ruleHashes.forEach { ruleHash in
                downloadingGroup.enter()
                if !DCCDataCenter.localDataManager.isRuleExistWithHash(hash: ruleHash.hash) {
                    getRules(ruleHash: ruleHash) { rule, error in
                        if let rule = rule {
                            rulesItems.append(rule)
                        }
                        downloadingGroup.leave()
                    }
                } else {
                    downloadingGroup.leave()
                }
            }
            downloadingGroup.notify(queue: .main) {
              completion(rulesItems.resultArray, nil)
              DGCLogger.logInfo("Finished all rules requests.")
            }
        }
    }
    
    static func getRules(ruleHash: RuleHash, completion: @escaping RuleCompletionHandler) {
        request(["endpoints", "rules"], externalLink: "/\(ruleHash.country)/\(ruleHash.hash)", method: .get).response {
            guard case let .success(result) = $0.result,
                  let response = result, let responseStr = String(data: response, encoding: .utf8)
            else {
                completion(nil, GatewayError.parsingError)
                return
            }
            if let rule: Rule = CertLogicEngine.getItem(from: responseStr) {
                let downloadedRuleHash = SHA256.digest(input: response as NSData)
                if downloadedRuleHash.hexString == ruleHash.hash {
                  rule.setHash(hash: ruleHash.hash)
                  completion(rule, nil)
                } else {
                    completion(nil, GatewayError.encodingError)
                }
            } else {
                completion(nil, GatewayError.encodingError)
            }
        }
    }

    static func loadRulesFromServer(completion: @escaping RulesCompletion) {
        getListOfRules { rulesList, error in
            guard error == nil else {
                completion(nil, GatewayError.connection(error: error!))
                return
            }
            guard let rules = rulesList else {
                completion(nil, GatewayError.parsingError)
                return
            }
            DCCDataCenter.addRules(rules)
            completion(DCCDataCenter.rules, nil)
        }
    }

    // MARK: Valuesets
    static private func getListOfValueSets(completion: @escaping ValueSetsCompletion) {
        request(["endpoints", "valuesets"], method: .get).response {
            guard case let .success(result) = $0.result,
                let response = result,
                let responseStr = String(data: response, encoding: .utf8)
            else {
                completion(nil, GatewayError.parsingError)
                return
            }
            let valueSetsHashes: [ValueSetHash] = CertLogicEngine.getItems(from: responseStr)
            // Remove old hashes
            DCCDataCenter.valueSets = DCCDataCenter.valueSets.filter { valueSet in
                return !valueSetsHashes.contains(where: { $0.hash == valueSet.hash })
            }
            // Downloading new hashes
            let valueSetsItems = SyncArray<ValueSet>()
            let downloadingGroup = DispatchGroup()
            valueSetsHashes.forEach { valueSetHash in
                downloadingGroup.enter()
                if !DCCDataCenter.localDataManager.isValueSetExistWithHash(hash: valueSetHash.hash) {
                    getValueSets(valueSetHash: valueSetHash) { valueSet, error in
                        if let valueSet = valueSet {
                          valueSetsItems.append(valueSet)
                        }
                        downloadingGroup.leave()
                    }
                } else {
                    downloadingGroup.leave()
                }
            }
            downloadingGroup.notify(queue: .main) {
                completion(valueSetsItems.resultArray, nil)
                DGCLogger.logInfo("Finished all value sets requests.")
            }
        }
    }

    static private func getValueSets(valueSetHash: ValueSetHash, completion: @escaping ValueSetCompletionHandler) {
        request(["endpoints", "valuesets"], externalLink: "/\(valueSetHash.hash)", method: .get).response {
            guard case let .success(result) = $0.result,
                let response = result,
                let responseStr = String(data: response, encoding: .utf8)
            else {
                completion(nil, .parsingError)
                return
            }
              
            if let valueSet: ValueSet = CertLogicEngine.getItem(from: responseStr) {
                let downloadedValueSetHash = SHA256.digest(input: response as NSData)
                if downloadedValueSetHash.hexString == valueSetHash.hash {
                    valueSet.setHash(hash: valueSetHash.hash)
                    completion(valueSet, nil)
                    return
                }
            }
            completion(nil, .insufficientData)
        }
    }

    static func loadValueSetsFromServer(completion: @escaping ValueSetsCompletion) {
        getListOfValueSets { list, error in
            guard error == nil else {
                completion(nil, .connection(error: error!))
                return
            }
            if let valueSetsList = list  {
                DCCDataCenter.addValueSets(valueSetsList)
            }
            completion(DCCDataCenter.valueSets, nil)
        }
    }
}