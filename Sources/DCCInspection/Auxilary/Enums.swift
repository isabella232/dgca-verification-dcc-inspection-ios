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
//  Enums.swift
//  
//
//  Created by Igor Khomiak on 15.10.2021.
//

import Foundation

public enum ClaimKey: String {
  case hCert = "-260"
  case euDgcV1 = "1"
}

public enum HCertType: String {
  case test
  case vaccine
  case recovery
  case unknown
}

public enum RevocationMode: String {
    case point = "POINT"
    case vector = "VECTOR"
    case coordinate = "COORDINATE"
}

public enum Icons: String {
  case ok = "\u{f00c}"
  case limited = "\u{f128}"
  case error = "\u{f05e}"
}

public var sliceType: SliceType = .BLOOMFILTER

public enum SliceType: String {
   case BLOOMFILTER, VARHASHLIST
}
