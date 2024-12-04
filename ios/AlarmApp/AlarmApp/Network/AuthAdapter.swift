//
//  Copyright (c) 2022 Software AG, Darmstadt, Germany and/or its licensors
//
//  SPDX-License-Identifier: Apache-2.0
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import CumulocityCoreLibrary
import Foundation

protocol AuthAdapter {
    @discardableResult
    func applyAuth(_ request: URLRequestBuilder, credentials: Credentials) -> URLRequestBuilder

    @discardableResult
    func applyAuth(_ request: URLRequest, credentials: Credentials) -> URLRequest
}

class BasicAuthAdapter: NSObject, AuthAdapter {
    func applyAuth(_ requestBuilder: URLRequestBuilder, credentials: Credentials) -> URLRequestBuilder {
        if let header = basicAuthHeader(credentials) {
            _ = requestBuilder.add(header: "Authorization", value: header)
        }
        return requestBuilder
    }

    @discardableResult
    func applyAuth(_ request: URLRequest, credentials: Credentials) -> URLRequest {
        var mutableRequest = request
        if let header = basicAuthHeader(credentials) {
            mutableRequest.addValue(header, forHTTPHeaderField: "Authorization")
        }
        return mutableRequest
    }

    internal func basicAuthHeader(_ credentials: Credentials) -> String? {
        let userName = credentials.userName
        let password = credentials.password
        let credentials = "\(userName):\(password)"

        if let encodedCredentials = credentials.data(using: .utf8) {
            return "Basic " + encodedCredentials.base64EncodedString()
        }

        return nil
    }
}

class OAuthInternalAdapter: NSObject, AuthAdapter {
    func applyAuth(_ requestBuilder: URLRequestBuilder, credentials: Credentials) -> URLRequestBuilder {
        if let authorization = credentials.authorization?.value, let xsrfToken = credentials.xsrfToken?.value {
            let cookiesHeader = createCookiesHeader(from: [
                "authorization": authorization,
                "XSRF-TOKEN": xsrfToken,
            ])
            _ = requestBuilder.add(header: "Cookie", value: cookiesHeader)
            _ = requestBuilder.add(header: "X-XSRF-TOKEN", value: xsrfToken)
        }

        _ = requestBuilder.add(header: "usexbasic", value: "true")
        return requestBuilder
    }

    func applyAuth(_ request: URLRequest, credentials: Credentials) -> URLRequest {
        var mutableRequest = request
        if let authorization = credentials.authorization?.value, let xsrfToken = credentials.xsrfToken?.value {
            let cookiesHeader = createCookiesHeader(from: [
                "authorization": authorization,
                "XSRF-TOKEN": xsrfToken,
            ])
            mutableRequest.addValue(cookiesHeader, forHTTPHeaderField: "Cookie")
            mutableRequest.addValue(xsrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
            mutableRequest.addValue("true", forHTTPHeaderField: "usexbasic")
        }
        return mutableRequest
    }

    internal func createCookiesHeader(from cookies: [String: String]) -> String {
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }
}
