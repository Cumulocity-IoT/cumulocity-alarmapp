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
    struct LoginFailedError: Error {}

    private static var sharedCumulocityApi: CumulocityApi = {
        C8yManagedObject.registerAdditionalProperty(typeName: C8yFragments.type.rawValue, for: String.self)
        C8yManagedObject.registerAdditionalProperty(typeName: C8yFragments.c8yHardware.rawValue, for: C8yHardware.self)
        C8yAlarm.registerAdditionalProperty(typeName: C8yComment.identifier, for: [C8yComment].self)

        return CumulocityApi()
    }()

    var userId: String = ""
    var credentials: Credentials?

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

    func initRequestBuilder(forCredentials credentials: Credentials) {
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

        if let authorization = credentials.authorization, let xsrfToken = credentials.xsrfToken {
            let cookiesHeader = createCookiesHeader(from: [
                "authorization": authorization,
                "XSRF-TOKEN": xsrfToken,
            ])
            _ = Cumulocity.Core.shared.requestBuilder.add(header: "Cookie", value: cookiesHeader)
            _ = Cumulocity.Core.shared.requestBuilder.add(header: "X-XSRF-TOKEN", value: xsrfToken)
        }

        _ = Cumulocity.Core.shared.requestBuilder.add(header: "usexbasic", value: "true")

        //        _ = Cumulocity.Core.shared.requestBuilder.set(
        //            authorization: credentials.userName,
        //            password: credentials.password
        //        )
    }

    func createCookiesHeader(from cookies: [String: String]) -> String {
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    func login(
        credentials: Credentials,
        loginOption: C8yLoginOption? = nil
    ) async throws {
        guard let url = URL(string: loginOption?.initRequest ?? credentials.tenant) else {
            return
        }

        let loginParameter: [String: String?] = [
            "grant_type": "PASSWORD",
            "username": credentials.userName,
            "password": credentials.password,
            "tfa_code": credentials.otp,
        ]

        let body =
            loginParameter
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
            .data(using: .utf8) ?? Data()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "post"
        urlRequest.httpBody = body
        urlRequest.addValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("true", forHTTPHeaderField: "usexbasic")

        print(urlRequest.url?.absoluteString ?? "No URL")

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

                let cookies = self.createHTTPCookies(from: setCookieString, for: url)
                print(cookies)
                //                for cookie in cookies {
                //                    HTTPCookieStorage.shared.setCookie(cookie)
                //                }
                //
                let authorization = cookies["authorization"]
                let xsrf_token = cookies["XSRF-TOKEN"]
                print(authorization)
                print(xsrf_token)
                guard let authorization else { throw LoginFailedError() }
                guard let xsrf_token else { throw LoginFailedError() }

                credentials.authorization = authorization.value
                credentials.xsrfToken = xsrf_token.value
                print(credentials)

                self.initRequestBuilder(forCredentials: credentials)

                return true
            })
            .eraseToAnyPublisher()
            .awaitValue()
    }

    func createHTTPCookies(from setCookieString: String, for url: URL) -> [String: HTTPCookie] {
        let cookieStrings = setCookieString.components(separatedBy: ", ")
        var cookies = [String: HTTPCookie]()

        for cookieString in cookieStrings {
            let cookieComponents = cookieString.components(separatedBy: ";")
            var cookieProperties = [HTTPCookiePropertyKey: Any]()

            for (index, component) in cookieComponents.enumerated() {
                let keyValue = component.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                if index == 0, keyValue.count == 2 {
                    cookieProperties[.name] = keyValue[0]
                    cookieProperties[.value] = keyValue[1]
                } else if keyValue.count == 2 {
                    let key = keyValue[0].lowercased()
                    let value = keyValue[1]
                    switch key {
                    case "domain":
                        cookieProperties[.domain] = value
                    case "path":
                        cookieProperties[.path] = value
                    case "expires":
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "EEE, dd-MMM-yyyy HH:mm:ss zzz"
                        if let date = dateFormatter.date(from: value) {
                            cookieProperties[.expires] = date
                        }
                    case "max-age":
                        if let maxAge = TimeInterval(value) {
                            cookieProperties[.expires] = Date().addingTimeInterval(maxAge)
                        }
                    case "secure":
                        cookieProperties[.secure] = true
                    //                                    case "httponly":
                    //                                        cookieProperties[.isHTTPOnly] = true
                    default:
                        break
                    }
                }
            }

            cookieProperties[.originURL] = url
            cookieProperties[.version] = 0

            if let cookie = HTTPCookie(properties: cookieProperties) {
                cookies[cookie.name] = cookie
            }
        }

        return cookies
    }
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
