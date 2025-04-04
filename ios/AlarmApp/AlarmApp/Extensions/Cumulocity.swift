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

import Combine
import CumulocityCoreLibrary
import Foundation
import os

extension Cumulocity {
    public static var measurementDateFormatter: ISO8601DateFormatter = {
        var formatter = ISO8601DateFormatter()

        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withFractionalSeconds, .withFullDate, .withFullTime, .withColonSeparatorInTimeZone]
        return formatter
    }()

    public static func formattedDate(dateString: String?) -> String {
        let dateFormatter = Cumulocity.measurementDateFormatter
        guard let t = dateString else { return "" }
        guard let d = dateFormatter.date(from: t) else { return t }
        return d.formatted()
    }
}

// MARK: - Custom Requests
extension Cumulocity {
    struct InvalidURLError: Error {}

    static func getLoginOptions(url: URL) async throws -> [String: C8yLoginOption]? {
        guard let host = url.host else {
            throw InvalidURLError()
        }

        let builder = URLRequestBuilder()
            .set(scheme: url.scheme ?? "https")
            .set(host: host)

        let api = LoginOptionsApi(requestBuilder: builder)
        return try await api.getLoginOptions()
            .map { collection -> [String: C8yLoginOption]? in
                collection.loginOptions?
                    .filter {
                        $0.userManagementSource == "INTERNAL"
                    }
                    .reduce(into: [String: C8yLoginOption]()) { dict, opt in
                        if let type = opt.type {
                            dict[type] = opt
                        }
                    }
            }
            .eraseToAnyPublisher()
            .awaitValue()
    }

}

// MARK: - Combine Publisher Extensions
private class AwaitWrapper {
    var cancellable: AnyCancellable?
    var didReceiveValue = false

    struct MissingOutputError: Error {}
}

extension Publisher {
    @discardableResult
    func awaitValue() async throws -> Output {
        let cancellableWrapper = AwaitWrapper()

        try Task.checkCancellation()

        return try await withTaskCancellationHandler(
            handler: {
                cancellableWrapper.cancellable?.cancel()
            },
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    guard !Task.isCancelled else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    cancellableWrapper.cancellable = handleEvents(receiveCancel: {
                        continuation.resume(throwing: CancellationError())
                    })
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                continuation.resume(throwing: error)

                            case .finished:
                                if !cancellableWrapper.didReceiveValue {
                                    continuation.resume(
                                        throwing: AwaitWrapper.MissingOutputError()
                                    )
                                }
                            }
                        },
                        receiveValue: { value in
                            guard !cancellableWrapper.didReceiveValue else { return }
                            cancellableWrapper.didReceiveValue = true
                            continuation.resume(returning: value)
                        }
                    )
                }
            }
        )
    }
}

extension Publisher where Output == URLSession.DataTaskPublisher.Output {
    func data() -> AnyPublisher<Data, Error> {
        tryMap { element in
            guard let httpResponse = element.response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard (200..<300) ~= httpResponse.statusCode else {
                if let c8yError = try? JSONDecoder().decode(C8yError.self, from: element.data) {
                    c8yError.httpResponse = httpResponse
                    throw c8yError
                }
                throw BadResponseError(with: httpResponse)
            }
            return element.data
        }
        .eraseToAnyPublisher()
    }
}

extension Publisher where Output == Data {
    func printData(prefix: String = "", quiet: Bool = false) -> AnyPublisher<Data, Failure> {
        map { data -> Data in
            if !quiet {
                Swift.print("\(prefix) \(String(data: data, encoding: .utf8) ?? "")")
            }
            return data
        }
        .eraseToAnyPublisher()
    }
}
