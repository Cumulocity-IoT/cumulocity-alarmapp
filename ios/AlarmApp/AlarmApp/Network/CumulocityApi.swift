//  Copyright (c) 2023 Software AG, Darmstadt, Germany and/or its licensors
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

class CumulocityApi {
    private static var sharedCumulocityApi: CumulocityApi = {
        C8yManagedObject.registerAdditionalProperty(typeName: C8yFragments.type.rawValue, for: String.self)
        C8yManagedObject.registerAdditionalProperty(typeName: C8yFragments.c8yHardware.rawValue, for: C8yHardware.self)
        C8yAlarm.registerAdditionalProperty(typeName: C8yComment.identifier, for: [C8yComment].self)

        return CumulocityApi()
    }()

    var userId: String = ""
    var credentials: Credentials?
    var loginOption: C8yLoginOption?

    var authAdapter: [String: AuthAdapter] = [
        "BASIC": BasicAuthAdapter(),
        "OAUTH2_INTERNAL": OAuthInternalAdapter(),
    ]

    private init() {
        let configuration = URLSessionConfiguration.default
        Cumulocity.Core.shared.session = URLSession(
            configuration: configuration,
            delegate: Delegate(),
            delegateQueue: nil
        )
    }

    class func shared() -> CumulocityApi {
        sharedCumulocityApi
    }

    func initRequestBuilder(forCredentials credentials: Credentials, loginOption: C8yLoginOption? = nil) {
        self.credentials = credentials

        guard let url = URL(string: credentials.tenant) else {
            return
        }

        if let host = url.host {
            _ = Cumulocity.Core.shared.requestBuilder.set(host: host)
        }

        if let scheme = url.scheme {
            _ = Cumulocity.Core.shared.requestBuilder.set(scheme: scheme)
        }

        let requestBuilder = Cumulocity.Core.shared.requestBuilder
        if let type = loginOption?.type, let adapter = self.authAdapter[type] {
            adapter.applyAuth(requestBuilder, credentials: credentials)
        } else {
            if credentials.authorization != nil, credentials.xsrfToken != nil {
                authAdapter["OAUTH2_INTERNAL"]?.applyAuth(requestBuilder, credentials: credentials)
            } else {
                authAdapter["BASIC"]?.applyAuth(requestBuilder, credentials: credentials)
            }
        }
    }

    func login(credentials: Credentials, loginOption: C8yLoginOption? = nil) async throws {
        guard let r = loginOption?.initRequest, let url = URL(string: r) else {
            throw InvalidTenantURLError()
        }

        guard
            let body = self.formEncodedBody(from: [
                "grant_type": "PASSWORD",
                "username": credentials.userName,
                "password": credentials.password,
                "tfa_code": credentials.otp,
            ])
        else {
            throw LoginFailedError()
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "post"
        urlRequest.httpBody = body
        urlRequest.addValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("true", forHTTPHeaderField: "usexbasic")

        try await URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap({ element -> Bool in
                guard let httpResponse = element.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw LoginFailedError()
                }

                guard let setCookieString = httpResponse.value(forHTTPHeaderField: "Set-Cookie") else {
                    throw LoginFailedError()
                }

                let cookies = self.parseCookies(from: setCookieString, for: url)

                guard let authorization = cookies["authorization"] else { throw LoginFailedError() }
                guard let xsrf_token = cookies["XSRF-TOKEN"] else { throw LoginFailedError() }

                credentials.authorization = authorization
                credentials.xsrfToken = xsrf_token
                self.initRequestBuilder(forCredentials: credentials, loginOption: loginOption)

                return true
            })
            .eraseToAnyPublisher()
            .awaitValue()
    }

    internal func parseCookies(from setCookieString: String, for url: URL) -> [String: HTTPCookie] {
        let headerFields = ["Set-Cookie": setCookieString]
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: url
        ).reduce(into: [String: HTTPCookie]()) { dict, cookie in
            dict[cookie.name] = cookie
        }
        return cookies
    }

    internal func formEncodedBody(from parameters: [String: String?]) -> Data? {
        return
            parameters
            .map { key, value in
                guard let value = value else { return nil }
                guard
                    let e = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?.replacingOccurrences(
                        of: "&",
                        with: "%26"
                    )
                else { return nil }
                return "\(key)=\(e)"
            }
            .compactMap { $0 }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

extension CumulocityApi {
    struct LoginFailedError: Error {}
    struct InvalidTenantURLError: Error {}
}

class Delegate: NSObject, URLSessionDelegate {
    let allowedDomains: [String]?

    override init() {
        let configuration = Bundle.main.cumulocityConfiguration()
        self.allowedDomains = configuration?["Allowed Domains"] as? [String]
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if allowedDomains?.contains(challenge.protectionSpace.host) ?? false {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
