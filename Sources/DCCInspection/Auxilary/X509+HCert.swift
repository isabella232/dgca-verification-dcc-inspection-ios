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
//  X509+HCert.swift
//  
//
//  Created by Igor Khomiak on 30.03.2022.
//

import Foundation

public extension X509 {
    static func checkisSuitable(cert: String, certType: HCertType) -> Bool{
        return isSuitable(cert: Data(base64Encoded:  cert)!, for: certType)
    }

    static func isCertificateValid(cert: String) -> Bool {
        guard let data = Data(base64Encoded:  cert) else { return true }
        guard let certificate = try? X509Certificate(data: data) else { return false }
      
        if (certificate.notAfter ?? Date()) > Date() {
          return true
        } else {
          return false
        }
    }

    static func isSuitable(cert: Data,for certType: HCertType) -> Bool {
      guard let certificate = try? X509Certificate(data: cert) else { return false }
        
      if isType(in: certificate) {
        switch certType {
        case .test:
          return nil != certificate.extensionObject(oid: OID_TEST) || nil != certificate.extensionObject(oid: OID_ALT_TEST)
        case .vaccine:
          return nil != certificate.extensionObject(oid: OID_VACCINATION) || nil != certificate.extensionObject(oid: OID_ALT_VACCINATION)
        case .recovery:
          return nil != certificate.extensionObject(oid: OID_RECOVERY) || nil != certificate.extensionObject(oid: OID_ALT_RECOVERY)
        case .unknown:
          return false
        }
      }
      return true
    }
}
