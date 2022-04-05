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
import JWTDecode

public enum GatewayError: Error {
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

public typealias GatewayCompletion = (GatewayError?) -> Void
public typealias CertUpdateCompletion = (String?, String?, GatewayError?) -> Void

public typealias CertStatusCompletion = ([String]?, GatewayError?) -> Void
public typealias ValueSetsCompletion = ([ValueSet]?, GatewayError?) -> Void
public typealias ValueSetCompletionHandler = (ValueSet?, GatewayError?) -> Void
public typealias RulesCompletion = ([Rule]?, GatewayError?) -> Void
public typealias RuleCompletionHandler = (Rule?, GatewayError?) -> Void
public typealias CountryCompletionHandler = ([CountryModel]?, GatewayError?) -> Void

public class GatewayConnection: ContextConnection {
    public static func certUpdate(resume resumeToken: String? = nil, completion: @escaping CertUpdateCompletion) {
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
    
    public static func certStatus(resume resumeToken: String? = nil, completion: @escaping CertStatusCompletion) {
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
    
    public static func updateLocalDataStorage(completion: @escaping GatewayCompletion) {
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

    public static var config: JSON {
        return DCCDataCenter.localDataManager.versionedConfig
    }
}

// MARK: Country, Rules, Valuesets extension
public extension GatewayConnection {
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

public extension GatewayConnection {
    static func claim(cert: HCert, with tan: String?, completion: @escaping ContextCompletion) {
        guard var tan = tan, !tan.isEmpty else {
            completion(false, nil, GatewayError.insufficientData)
            return
        }
        
        // Replace dashes, spaces, etc. and turn into uppercase.
        let set = CharacterSet(charactersIn: "0123456789").union(.uppercaseLetters)
        tan = tan.uppercased().components(separatedBy: set.inverted).joined()
        
        let tanHash = SHA256.stringDigest(input: Data(tan.data(using: .utf8) ?? .init()))
        let certHash = cert.certHash
        let pubKey = (X509.derPubKey(for: cert.keyPair) ?? Data()).base64EncodedString()
        
        let toBeSigned = tanHash + certHash + pubKey
        let toBeSignedData = Data(toBeSigned.data(using: .utf8) ?? .init())
        
        Enclave.sign(data: toBeSignedData, with: cert.keyPair, using: .ecdsaSignatureMessageX962SHA256) { sign, err in
            guard err == nil else {
                completion(false, nil, GatewayError.local(description: err!))
                return
            }
            guard let sign = sign else {
                completion(false, nil, GatewayError.local(description: "No sign"))
                return
            }
            let keyParam: [String: Any] = [ "type": "EC", "value": pubKey ]
            let param: [String: Any] = [
                "DGCI": cert.uvci,
                "TANHash": tanHash,
                "certhash": certHash,
                "publicKey": keyParam,
                "signature": sign.base64EncodedString(),
                "sigAlg": "SHA256withECDSA"
            ]
            request( ["endpoints", "claim"], method: .post, parameters: param, encoding: JSONEncoding.default,
                     headers: HTTPHeaders([HTTPHeader(name: "content-type", value: "application/json")])).response {
                guard case .success(_) = $0.result, let status = $0.response?.statusCode, status / 100 == 2 else {
                    completion(false, nil, GatewayError.local(description: "Cannot claim certificate"))
                    return
                }
                let response = String(data: $0.data ?? .init(), encoding: .utf8)
                let json = JSON(parseJSON: response ?? "")
                let newTAN = json["tan"].string
                completion(true, newTAN, nil)
            }
        }
    }
    
	static func lookup(certStrings: [DatedCertString], completion: @escaping ContextCompletion) {
			 guard certStrings.count != 0 else { completion(true, nil, nil); return; }
			// construct certs from strings
			var certs: [Date: HCert] = [:]
			for string in certStrings {
				guard let c = string.cert else { completion(false, nil, nil); return; }
				// certs.append(c)
				certs[string.date] = c
			}
			
			DGCAJwt.makeJwtAndSign(fromCerts: Array(certs.values)) { success, jwts, error in
				guard let jwts = jwts,
					  success == true,
					  error == nil else {
						  completion(false, nil, GatewayError.local(description: "JWT creation failed!"))
						  return
					  }
				// let param = ["value": jwts]
				var request = URLRequest(url: URL(string: "https://dgca-revocation-service-eu-test.cfapps.eu10.hana.ondemand.com/revocation/lookup")!)
				request.httpMethod = "POST"
				request.setValue("application/json", forHTTPHeaderField: "Content-Type")
				request.httpBody = try! JSONSerialization.data(withJSONObject: jwts)
				AF.request(request).response {
					guard
						case .success(_) = $0.result,
						let status = $0.response?.statusCode,
						let response = try? JSONSerialization.jsonObject(with: $0.data ?? .init(), options: []) as? [String],
						status / 100 == 2
					else {
						completion(false, nil, nil)
						return
					}
					if response.count == 0 { completion(true, nil, nil); return }
					// response is list of hashes that have been revoked
					var count = certs.count
					let revokedHashes = response as [String]
					// identify all certs that have changed
					var toBeChanged: [Date: HCert] = [:]
					certs.forEach { date, cert in
						if revokedHashes.contains(cert.uvciHash![0..<cert.uvciHash!.count/2].toHexString()) ||
							revokedHashes.contains(cert.signatureHash![0..<cert.signatureHash!.count/2].toHexString()) ||
							revokedHashes.contains(cert.countryCodeUvciHash![0..<cert.countryCodeUvciHash!.count/2].toHexString()) {
							cert.isRevoked = true
							toBeChanged[date] = cert
						} else {
							if cert.isRevoked {
								cert.isRevoked = false
								toBeChanged[date] = cert
							}
						}
					}
					
					toBeChanged.forEach { date, cert in
						DCCDataCenter.localDataManager.remove(withDate: date) { status in
							guard case .success(_) = status else { completion(false, nil, nil); return }
							var storedTan: String!
							certStrings.forEach { certString in
								if certString.cert!.certHash.elementsEqual(cert.certHash) {
									storedTan = certString.storedTAN ?? ""
								}
							}
							DCCDataCenter.localDataManager.add(cert, with: storedTan) { status in
								guard case .success(_) = status else { completion(false, nil, nil); return }
								if count == 0 {
									completion(true, nil, nil)
								}
							}
						}
					}
				}
			}
		}
}

public typealias TicketingCompletion = (AccessTokenResponse?, GatewayError?) -> Void
public typealias ContextCompletion = (Bool, String?, GatewayError?) -> Void

public extension GatewayConnection {
    static func loadAccessToken(_ url : URL, servicePath : String, publicKey: String, completion: @escaping TicketingCompletion) {
        let json: [String: Any] = ["service": servicePath, "pubKey": publicKey]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json,options: .prettyPrinted),
              let tokenData = SecureKeyChain.load(key: SharedConstants.keyTicketingToken)  else {
                  completion(nil, GatewayError.tokenError)
                  return
              }
        let token = String(decoding: tokenData, as: UTF8.self)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue( "1.0.0", forHTTPHeaderField: "X-Version")
        request.addValue( "application/json", forHTTPHeaderField: "content-type")
        request.addValue( "Bearer " + token, forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(nil, GatewayError.connection(error: error!))
                return
            }
            guard let responseData = data, let tokenJWT = String(data: responseData, encoding: .utf8), responseData.count > 0 else {
                completion(nil, GatewayError.incorrectDataResponse)
                return
            }
            do {
                let decodedToken = try decode(jwt: tokenJWT)
                let jsonData = try JSONSerialization.data(withJSONObject: decodedToken.body)
                let accessTokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: jsonData)
                
                if let tokenData = tokenJWT.data(using: .utf8) {
                    SecureKeyChain.save(key: SharedConstants.keyAccessToken, data: tokenData)
                }
                if let httpResponse = response as? HTTPURLResponse,
                   let xnonceData = (httpResponse.allHeaderFields["x-nonce"] as? String)?.data(using: .utf8) {
                    SecureKeyChain.save(key: SharedConstants.keyXnonce, data: xnonceData)
                }
                completion(accessTokenResponse, nil)
                
            } catch {
                completion(nil, GatewayError.encodingError)
                DGCLogger.logError(error)
            }
        })
        session.resume()
    }
    
    static func validateTicketing(url : URL, parameters : [String: String]?, completion : @escaping TicketingCompletion) {
        guard let parametersData = try? JSONEncoder().encode(parameters) else {
            completion(nil, GatewayError.encodingError)
            return
        }
        guard let tokenData = SecureKeyChain.load(key: SharedConstants.keyAccessToken) else {
            completion(nil, GatewayError.tokenError)
            return
        }
        let token = String(decoding: tokenData, as: UTF8.self)
        var request = URLRequest(url: url)
        request.method = .post
        request.httpBody = parametersData
        
        request.addValue( "1.0.0", forHTTPHeaderField: "X-Version")
        request.addValue( "application/json", forHTTPHeaderField: "content-type")
        request.addValue( "Bearer " + token, forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            guard error == nil else {
                completion(nil,GatewayError.connection(error: error!))
                return
            }
            guard let responseData = data, let tokenJWT = String(data: responseData, encoding: .utf8) else {
                completion(nil, GatewayError.incorrectDataResponse)
                return
            }
            do {
                let decodedToken = try decode(jwt: tokenJWT)
                let jsonData = try JSONSerialization.data(withJSONObject: decodedToken.body)
                let decoder = JSONDecoder()
                let accessTokenResponse = try decoder.decode(AccessTokenResponse.self, from: jsonData)
                completion(accessTokenResponse, nil)
                
            } catch {
                completion(nil, GatewayError.parsingError)
                DGCLogger.logError(error)
            }
        })
        session.resume()
    }
}
