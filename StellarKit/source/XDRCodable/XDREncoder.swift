//
//  XDREncoder.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

/*
 Based on: https://github.com/mikeash/BinaryCoder
 */

import CoreFoundation

/// A protocol for types which can be encoded to binary.
public protocol XDREncodable: Encodable {
    func xdrEncode(to encoder: XDREncoder) throws
}

/// Provide a default implementation which calls through to `Encodable`. This
/// allows `XDREncodable` to use the `Encodable` implementation generated by the
/// compiler.
public extension XDREncodable {
    func xdrEncode(to encoder: XDREncoder) throws {
        try self.encode(to: encoder)
    }
}

/// The actual binary encoder class.
public class XDREncoder {
    fileprivate var data: [UInt8] = []
    
    public init() {}
}

/// A convenience function for creating an encoder, encoding a value, and
/// extracting the resulting data.
public extension XDREncoder {
    static func encode(_ value: XDREncodable) throws -> [UInt8] {
        let encoder = XDREncoder()
        try value.xdrEncode(to: encoder)
        return encoder.data
    }
}

/// The error type.
public extension XDREncoder {
    /// All errors which `XDREncoder` itself can throw.
    enum Error: Swift.Error {
        /// Attempted to encode a type which is `Encodable`, but not `XDREncodable`. (We
        /// require `XDREncodable` because `XDREncoder` doesn't support full keyed
        /// coding functionality.)
        case typeNotConformingToXDREncodable(Any.Type)
    }
}

/// Methods for encoding various types.
public extension XDREncoder {
    func encode(_ value: Bool) throws {
        try encode(Int32(value ? 1 : 0))
    }
    
    func encode(_ value: Float) {
        appendBytes(of: CFConvertFloatHostToSwapped(value))
    }
    
    func encode(_ value: Double) {
        appendBytes(of: CFConvertDoubleHostToSwapped(value))
    }
    
    func encode(_ encodable: Encodable) throws {
        switch encodable {
        case let v as UInt8:
            v.xdrEncode(to: self)

        case let v as Float:
            encode(v)
            
        case let v as Double:
            encode(v)
            
        case let v as Bool:
            try encode(v)

        case let binary as XDREncodable:
            try binary.xdrEncode(to: self)
            
        default:
            throw Error.typeNotConformingToXDREncodable(type(of: encodable))
        }
    }
    
    /// Append the raw bytes of the parameter to the encoder's data. No byte-swapping
    /// or other encoding is done.
    func appendBytes<T>(of: T) {
        var target = of
        withUnsafeBytes(of: &target) {
            data.append(contentsOf: $0)
        }
    }
}

extension XDREncoder: Encoder {
    public var codingPath: [CodingKey] { return [] }
    
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(KeyedContainer<Key>(encoder: self))
    }
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }
    
    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var encoder: XDREncoder
        
        var codingPath: [CodingKey] { return [] }
        
        func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            try encoder.encode(value)
        }
        
        func encodeNil(forKey key: Key) throws {
            return try encode(Int32(0), forKey: key)
        }
        
        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            return encoder.container(keyedBy: keyType)
        }
        
        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            return encoder.unkeyedContainer()
        }
        
        func superEncoder() -> Encoder {
            return encoder
        }
        
        func superEncoder(forKey key: Key) -> Encoder {
            return encoder
        }
    }
    
    private struct UnkeyedContanier: UnkeyedEncodingContainer, SingleValueEncodingContainer {
        var encoder: XDREncoder
        
        var codingPath: [CodingKey] { return [] }
        
        var count: Int { return 0 }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            return encoder.container(keyedBy: keyType)
        }
        
        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            return self
        }
        
        func superEncoder() -> Encoder {
            return encoder
        }
        
        func encodeNil() throws {
            return try encode(Int32(0))
        }
        
        func encode<T>(_ value: T) throws where T : Encodable {
            try encoder.encode(value)
        }
    }
}
