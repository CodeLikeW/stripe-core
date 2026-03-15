//
//  StripeCodable.swift
//  StripeCore
//
//  Created by David Estes on 7/20/21.
//  Copyright © 2021 Stripe, Inc. All rights reserved.
//

// This contains ~most of our custom encoding/decoding logic for handling unknown fields.
//
// It isn't intended for public use, but exposing objects with this protocol
// requires that we make the protocol itself public.
//

import Foundation

/// A Decodable object that retains unknown fields.
/// :nodoc:
public protocol UnknownFieldsDecodable: Decodable, Sendable {
}

/// An Encodable object that allows unknown fields to be set.
/// :nodoc:
public protocol UnknownFieldsEncodable: Encodable, Sendable {
    /// This should not be used directly.
    /// Use the `additionalParameters` accessor instead.
    /// :nodoc:
}

/// A Decodable enum that sets an "unparsable" case
/// instead of failing on values that are unknown to the SDK.
/// :nodoc:
public protocol SafeEnumDecodable: Decodable {
    /// If the value is unparsable, the result will be available in
    /// the `allResponseFields` of the parent object.
    static var unparsable: Self { get }

    // It'd be nice to include the value of the unparsable enum
    // as an associated value, but Swift can't auto-generate the Codable
    // keys if we do that.
}

/// A Codable enum that sets an "unparsable" case
/// instead of failing on values that are unknown to the SDK.
/// :nodoc:
public protocol SafeEnumCodable: Encodable, SafeEnumDecodable {}

extension UnknownFieldsDecodable {

    static func decodedObject(jsonData: Data) throws -> Self {
        return try StripeJSONDecoder.decode(jsonData: jsonData)
    }
}

extension Encodable {
    func encodeJSONDictionary(includingUnknownFields: Bool = true) throws -> [String: Any] {
        let encoder = StripeJSONEncoder()
        return try encoder.encodeJSONDictionary(
            self
        )
    }
}

@_spi(STP) public enum UnknownFieldsCodableFloats: String {
    case PositiveInfinity = "Inf"
    case NegativeInfinity = "-Inf"
    case NaN = "nan"
}

/// A protocol that conforms to both UnknownFieldsEncodable and UnknownFieldsDecodable.
/// :nodoc:
public protocol UnknownFieldsCodable: UnknownFieldsEncodable, UnknownFieldsDecodable {}

/// This should not be used directly.
/// Use the `additionalParameters` and `allResponseFields` accessors instead.
/// :nodoc:
public struct NonEncodableParameters {
    @_spi(STP) public internal(set) var storage: [String: Any] = [:]
}

extension NonEncodableParameters: Decodable {
    /// :nodoc:
    public init(
        from decoder: Decoder
    ) throws {
        // no-op
    }
}

extension NonEncodableParameters: Encodable {
    /// :nodoc:
    public func encode(to encoder: Encoder) throws {
        // no-op
    }
}

extension NonEncodableParameters: Equatable {
    /// :nodoc:
    public static func == (lhs: NonEncodableParameters, rhs: NonEncodableParameters) -> Bool {
        return NSDictionary(dictionary: lhs.storage).isEqual(to: rhs.storage)
    }
}

// The default debugging behavior for structs is to print *everything*,
// which is undesirable as it could contain card numbers or other PII.
// For now, override it to just give an overview of the struct.
extension NonEncodableParameters: CustomStringConvertible, CustomDebugStringConvertible,
    CustomLeafReflectable
{
    /// :nodoc:
    public var customMirror: Mirror {
        return Mirror(reflecting: self.description)
    }

    /// :nodoc:
    public var debugDescription: String {
        return description
    }

    /// :nodoc:
    public var description: String {
        return "\(storage.count) fields"
    }
}

extension StripeJSONDecoder {
    static func decode<T: Decodable>(jsonData: Data) throws -> T {
        let decoder = StripeJSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
    }
}
