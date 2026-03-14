//
//  STPTelemetryClient.swift
//  StripeCore
//
//  Created by Ben Guo on 4/18/17.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

import Foundation

private let TelemetryURL = URL(string: "https://m.stripe.com/6")!

@_spi(STP) public final class STPTelemetryClient: NSObject {
    @MainActor @_spi(STP) public static var shared: STPTelemetryClient = STPTelemetryClient(
        sessionConfiguration: StripeAPIConfiguration.sharedUrlSessionConfiguration
    )

    @_spi(STP) public func addTelemetryFields(toParams params: inout [String: Any]) {
        let fraudData = fraudDetectionData()
        params["muid"] = fraudData.muid
        params["guid"] = fraudData.guid
        params["sid"] = fraudData.sid
    }

    @_spi(STP) public func paramsByAddingTelemetryFields(
        toParams params: [String: Any]
    ) -> [String: Any] {
        var mutableParams = params
        let fraudData = fraudDetectionData()
        mutableParams["muid"] = fraudData.muid
        mutableParams["guid"] = fraudData.guid
        mutableParams["sid"] = fraudData.sid
        return mutableParams
    }

    /// Sends a payload of telemetry to the Stripe telemetry service.
    ///
    /// - Parameters:
    ///   - completion: Called with the result of the telemetry network request.
    @MainActor @_spi(STP) public func sendTelemetryData(
        completion: (@Sendable (Result<[String: Any], Error>) -> Void)? = nil
    ) {
        let wrappedCompletion: (@Sendable (Result<[String: Any], Error>) -> Void) = { result in
            if case .failure(let error) = result {
                let errorAnalytic = ErrorAnalytic(event: .fraudDetectionApiFailure, error: error)
                Task { @MainActor in
                    STPAnalyticsClient.sharedClient.log(analytic: errorAnalytic)
                }
            }
            completion?(result)
        }

        guard STPTelemetryClient.shouldSendTelemetry() else {
            completion?(.failure(NSError.stp_genericConnectionError()))
            return
        }
        let payload = payload(deviceSupportsApplePay: StripeAPI.deviceSupportsApplePay())
        sendTelemetryRequest(jsonPayload: payload, completion: wrappedCompletion)
    }

    @_spi(STP) func updateFraudDetectionIfNecessary(
        completion: @escaping (@Sendable (Result<FraudDetectionData, Error>) -> Void)
    ) {
        let fraudData = fraudDetectionData()
        if fraudData.muid == nil || fraudData.sid == nil {
            sendTelemetryRequest(
                jsonPayload: [
                    "muid": fraudData.muid ?? "",
                    "guid": fraudData.guid ?? "",
                    "sid": fraudData.sid ?? "",
                ]) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        completion(.success(fraudData))
                    }
                }
        } else {
            completion(.success(fraudData))
        }
    }

    private let urlSession: URLSession
    @MainActor static var _forceShouldSendTelemetryInTests: Bool = false

    @MainActor @_spi(STP) public static func shouldSendTelemetry() -> Bool {
        return StripeAPI.advancedFraudSignalsEnabled && (NSClassFromString("XCTest") == nil || _forceShouldSendTelemetryInTests)
    }

    @_spi(STP) public init(
        sessionConfiguration config: URLSessionConfiguration
    ) {
        urlSession = URLSession(configuration: config)
        super.init()
    }

    private var language = Locale.autoupdatingCurrent.identifier
    private func fraudDetectionData() -> FraudDetectionData {
        FraudDetectionData().resetSIDIfExpired()
    }

    private var deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(
                to: CChar.self,
                capacity: 1
            ) { ptr in
                String(validatingCString: ptr)
            }
        }
        return model ?? "Unknown"
    }()

    private var timeZoneOffset: String {
        let timeZone = NSTimeZone.local as NSTimeZone
        let hoursFromGMT = Double(timeZone.secondsFromGMT) / (60 * 60)
        return String(format: "%.0f", hoursFromGMT)
    }

    private func encodeValue(_ value: String?) -> [AnyHashable: Any]? {
        if let value = value {
            return [
                "v": value,
            ]
        }
        return nil
    }

    private func payload(deviceSupportsApplePay: Bool) -> [String: Any] {
        var payload: [String: Any] = [:]
        var data: [String: Any] = [:]
        if let encode = encodeValue(language) {
            data["c"] = encode
        }
        if let encode = encodeValue(timeZoneOffset) {
            data["g"] = encode
        }
        payload["a"] = data

        // Don't pass expired SIDs to m.stripe.com
        let fraudData = fraudDetectionData()

        let otherData: [String: Any] = [
            "d": fraudData.muid ?? "",
            "e": fraudData.sid ?? "",
            "k": Bundle.stp_applicationName() ?? "",
            "l": Bundle.stp_applicationVersion() ?? "",
            "m": NSNumber(value: deviceSupportsApplePay),
            "s": deviceModel,
        ]
        payload["b"] = otherData
        payload["tag"] = STPAPIClient.STPSDKVersion
        payload["src"] = "ios-sdk"
        payload["v2"] = NSNumber(value: 1)
        return payload
    }

    private func sendTelemetryRequest(
        jsonPayload: [String: Any],
        completion: (@Sendable (Result<[String: Any], Error>) -> Void)? = nil
    ) {
        var request = URLRequest(url: TelemetryURL)
        let fraudData = fraudDetectionData()
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try? JSONSerialization.data(
            withJSONObject: jsonPayload,
            options: []
        )
        request.httpBody = data
        let task = urlSession.dataTask(with: request as URLRequest) { (data, response, error) in
            guard
                error == nil,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let data = data,
                let responseDict = try? JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any]
            else {
                completion?(.failure(error ?? NSError.stp_genericFailedToParseResponseError()))
                return
            }
            
            // Update fraudDetectionData
            let updatedData = fraudData.updateWith(sid: responseDict["sid"] as? String,
                                                   muid: responseDict["muid"] as? String,
                                                   guid: responseDict["guid"] as? String)
            UserDefaults.standard.saveFraudDetection(data: updatedData)
            completion?(.success(responseDict))
        }
        task.resume()
    }
}
