//
//  Cumulocity.swift
//  Cumulocity IoT Sensor App
//
//  Copyright (c) 2021 Software AG, Darmstadt, Germany and/or Software AG USA Inc., Reston, VA, USA, and/or its subsidiaries and/or its affiliates and/or their licensors.
//  Use, reproduction, transfer, publication or disclosure is prohibited except as specifically provided for in your License Agreement with Software AG.
//

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
    static func getTenantId(
        requestBuilder: URLRequestBuilder = Cumulocity.Core.shared.requestBuilder
    ) async throws -> String {
        // register properties required for decoding the fragements
        let api = TenantsApi(requestBuilder: requestBuilder)
        return try await api.getCurrentTenant()
            .tryMap { tenantOptions in
                guard let name = tenantOptions.name else {
                    throw Cumulocity.UnexpectedError()
                }
                return name
            }
            .eraseToAnyPublisher()
            .awaitValue()
    }

    static func getLoginOption(
        requestBuilder: URLRequestBuilder = Cumulocity.Core.shared.requestBuilder
    ) async throws -> C8yLoginOption? {
        let api = LoginOptionsApi(requestBuilder: requestBuilder)

        return try await api.getLoginOptions()
            .map { collection -> [C8yLoginOption] in
                collection.loginOptions?
                    .filter {
                        $0.visibleOnLoginPage == true && $0.userManagementSource == "INTERNAL"
                            && $0.type == "OAUTH2_INTERNAL"
                    } ?? []
            }
            .map(\.first)
            .eraseToAnyPublisher()
            .awaitValue()
    }
}

extension Cumulocity {
    struct UnexpectedError: Error {}
    struct LoginFailedError: Error {}
}

// MARK: - Combine Publisher Extensions
extension Publishers {
    struct MissingOutputError: Error {}
}

private class AwaitWrapper {
    var cancellable: AnyCancellable?
    var didReceiveValue = false
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
                                        throwing: Publishers.MissingOutputError()
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

    internal func delayFailure<T>(
        for delay: T.SchedulerTimeType.Stride,
        scheduler: T
    ) -> AnyPublisher<Output, Failure> where T: Scheduler {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard delay > 0 else {
                return self.eraseToAnyPublisher()
            }
            return Deferred {
                Future<Output, Failure> { completion -> Void in
                    scheduler.schedule(after: scheduler.now.advanced(by: delay)) {
                        completion(.failure(error))
                    }
                }
            }.eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func retryWithDelay(
        retries: Int,
        delay: Double,
        if condition: @escaping (Failure, Int) -> Bool = { _, _ in true }
    ) -> Publishers.DelayedRetry<Self, DispatchQueue> {
        Publishers.DelayedRetry(
            publisher: self,
            retries: retries,
            count: 0,
            delay: .seconds(delay),
            scheduler: DispatchQueue.main,
            condition: condition
        )
    }

    /// Use a serial queue, not a concurrent one as for example DispatchQueue.global()
    func retryWithDelay<T>(
        retries: Int,
        delay: T.SchedulerTimeType.Stride,
        scheduler: T,
        if condition: @escaping (Failure, Int) -> Bool = { _, _ in true }
    ) -> Publishers.DelayedRetry<Self, T> where T: Scheduler {
        Publishers.DelayedRetry(
            publisher: self,
            retries: retries,
            count: 0,
            delay: delay,
            scheduler: scheduler,
            condition: condition
        )
    }
}

extension Publishers {
    internal struct DelayedRetry<P: Publisher, T: Scheduler>: Publisher {
        typealias Output = P.Output
        typealias Failure = P.Failure

        let publisher: P
        let retries: Int
        let count: Int
        let delay: T.SchedulerTimeType.Stride
        let scheduler: T
        let condition: (P.Failure, Int) -> Bool

        func retryOrFail(_ error: P.Failure) -> AnyPublisher<P.Output, P.Failure> {
            if retries > 0 && !Task.isCancelled {
                return DelayedRetry(
                    publisher: publisher,
                    retries: retries - 1,
                    count: count + 1,
                    delay: delay,
                    scheduler: scheduler,
                    condition: condition
                )
                .eraseToAnyPublisher()
            } else {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }

        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            guard retries > 0 else { return publisher.receive(subscriber: subscriber) }

            if delay > 0 {
                return
                    publisher
                    .catch { (error: P.Failure) -> AnyPublisher<Output, Failure> in
                        if !condition(error, count + 1) {
                            return Fail(error: error).eraseToAnyPublisher()
                        }
                        return Just(())
                            .setFailureType(to: P.Failure.self)
                            .delay(for: delay, scheduler: scheduler)
                            .flatMap { _ in
                                retryOrFail(error).eraseToAnyPublisher()
                            }
                            .eraseToAnyPublisher()
                    }
                    .receive(subscriber: subscriber)
            } else {
                return publisher.catch { (error: P.Failure) -> AnyPublisher<Output, Failure> in
                    if !condition(error, count + 1) {
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    return retryOrFail(error)
                }
                .receive(subscriber: subscriber)
            }
        }
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

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
