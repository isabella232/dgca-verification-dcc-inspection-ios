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
//  RequestFactory.swift
//  DCCRevocation
//
//  Created by Igor Khomiak on 20.01.2022.
//

import Foundation

internal enum ServiceConfig: String {
    case test = "/"
    case linkForAllRevocations = "/lists"
    case linkForPartitions = "/lists/%@/partitions"
    case linkForPartitionsWithID =  "/lists/%@/partitions/%@"
    case linkForPartitionChunks = "/lists/%@/partitions/%@/slices"
    case linkForChunkSlices = "/lists/%@/partitions/%@/chunks/%@/slices"
    case linkForSingleSlice = "/lists/%@/partitions/%@/chunks/%@/slices/%@"
}

internal class RequestFactory {
    typealias StringDictionary = [String : String]

    // MARK: - Private methods
    fileprivate static func postRequest(url: URL, HTTPBody body: Data?, headerFields: StringDictionary?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        headerFields?.forEach { request.setValue($0.1, forHTTPHeaderField: $0.0) }
        return request
    }
    
    fileprivate static func request(url: URL, query: StringDictionary?, headerFields: StringDictionary?) -> URLRequest {
        var resultURL: URL = url
        if let query = query {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = query.map { URLQueryItem(name:$0.0, value: $0.1) }
            components?.queryItems = queryItems
            if let urlComponents = components?.url {
                resultURL = urlComponents
            }
        }
        
        var request = URLRequest(url: resultURL)
        request.httpMethod = "GET"
        
        headerFields?.forEach {
            request.setValue($0.1, forHTTPHeaderField: $0.0)
        }
        return request
    }
}

// TODO add protocol
extension RequestFactory {
    
    static func serviceGetRequest(path: String, etag: String? = nil) -> URLRequest? {
        guard let url = URL(string: path) else { return nil }
        
        let headers = etag == nil ? ["If-None-Match" : "", "Content-Type" : "application/json"] :
            ["If-Match" : etag!, "Content-Type" : "application/json"]
        
        let result = request(url: url, query: nil, headerFields: headers)
        return result
    }


    static func servicePostRequest(path: String, body: Data?, etag: String? = nil) -> URLRequest? {
        guard let url = URL(string: path) else { return nil }
 
        let headers = etag == nil ? ["If-None-Match" : "", "Content-Type" : "application/json"] :
            ["If-Match" : etag!, "Content-Type" : "application/json"]

        let result = postRequest(url: url, HTTPBody: body, headerFields: headers)
        return result
    }
}
