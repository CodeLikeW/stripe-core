//
//  PaymentsSDKVariant.swift
//  StripeCore
//
//  Copyright © 2022 Stripe, Inc. All rights reserved.
//

import Foundation

@_spi(STP) public class PaymentsSDKVariant {
    @_spi(STP) nonisolated public static let variant: String = {
        if NSClassFromString("STP_Internal_PaymentSheetViewController") != nil {
            // This is the PaymentSheet SDK
            return "paymentsheet"
        }
        if NSClassFromString("STPPaymentCardTextField") != nil {
            // This is the Payments UI SDK
            return "payments-ui"
        }
        if NSClassFromString("STPCardValidator") != nil {
            // This is the API-only Payments SDK
            return "payments-api"
        }
        if NSClassFromString("STPApplePayContext") != nil {
            // This is only the Apple Pay SDK
            return "applepay"
        }
        // This is a cryptid
        return "unknown"
    }()

    @MainActor @_spi(STP) public static var ocrTypeString: String {
        return "none"
    }

    @_spi(STP) nonisolated public static var paymentUserAgent: String {
        var paymentUserAgent = "stripe-ios/\(STPAPIClient.STPSDKVersion)"
        let variant = "variant.\(variant)"
        let components = [paymentUserAgent, variant]
        paymentUserAgent = components.joined(separator: "; ")
        return paymentUserAgent
    }
}
