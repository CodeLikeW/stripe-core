//
//  FraudDetectionData.swift
//  StripeCore
//
//  Created by Yuki Tokuhiro on 5/20/21.
//  Copyright © 2021 Stripe, Inc. All rights reserved.
//

import Foundation

private let SIDLifetime: TimeInterval = 30 * 60  // 30 minutes

/// Contains encoded values returned from m.stripe.com.
///
/// - Note: See `STPTelemetryClient`.
/// - Note: See `StripeAPI.advancedFraudSignalsEnabled`.
struct FraudDetectionData: Codable, Sendable, Equatable {
    
    var muid: String?
    var guid: String?
    var sid: String?
    /// The approximate time that the sid was generated from m.stripe.com
    /// Intended to be used to expire the sid after `SIDLifetime` seconds
    /// - Note: This class is a dumb container; users must set this value appropriately.
    var sidCreationDate: Date?
    
    init() {
        if let savedData = UserDefaults.standard.fraudDetectionData() {
            self = savedData
        } else {
            self = FraudDetectionData(sid: nil, muid: nil, guid: nil, sidCreationDate: nil)
        }
    }
    
    init(
        sid: String? = nil,
        muid: String? = nil,
        guid: String? = nil,
        sidCreationDate: Date? = nil
    ) {
        self.sid = sid
        self.muid = muid
        self.guid = guid
        self.sidCreationDate = sidCreationDate
    }
    
    func resetSIDIfExpired() -> FraudDetectionData {
        guard let sidCreationDate = sidCreationDate else {
            return self
        }
        let thirtyMinutesAgo = Date(timeIntervalSinceNow: -SIDLifetime)
        if sidCreationDate < thirtyMinutesAgo {
            return FraudDetectionData(sid: nil, muid: muid, guid: guid, sidCreationDate: sidCreationDate)
        }
        return self
    }
    
    func updateWith(sid: String?, muid: String?, guid: String?) -> FraudDetectionData {
        var fraudData = self
        if let sid {
            fraudData.sid = sid
            fraudData.sidCreationDate = Date()
        }
        if let muid {
            fraudData.muid = muid
        }
        if let guid {
            fraudData.guid = guid
        }
        return fraudData
    }
    
}
