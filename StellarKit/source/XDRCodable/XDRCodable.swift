//
//  XDRCodable.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public typealias XDRCodable = XDREncodable & XDRDecodable

public protocol XDREncodable {
    func encode(to encoder: XDREncoder) throws
}

public protocol XDRDecodable {
    init(from decoder: XDRDecoder) throws
}

public protocol XDREncodableStruct: XDREncodable {
}

extension XDREncodableStruct {
    public func encode(to encoder: XDREncoder) throws {
        for (_, value) in Mirror(reflecting: self).children {
            if let value = value as? XDREncodable {
                try value.encode(to: encoder)
            }
        }
    }
}

public class XDREncoder {
    private var data = Data()

    public static func encode<T>(_ value: T) throws -> Data where T: XDREncodable {
        let encoder = XDREncoder()

        try encoder.encode(value)

        return encoder.data
    }

    public static func encode<T>(_ value: T?) throws -> Data where T: XDREncodable {
        let encoder = XDREncoder()

        try encoder.encodeOptional(value)

        return encoder.data
    }

    func encode<T>(_ value: T) throws where T: XDREncodable {
        switch value {
        case let v as Bool: try v.encode(to: self)
        case let v as UInt8: try v.encode(to: self)
        case let v as Int32: try v.encode(to: self)
        case let v as UInt32: try v.encode(to: self)
        case let v as Int64: try v.encode(to: self)
        case let v as UInt64: try v.encode(to: self)
        case let v as String: try v.encode(to: self)
        case let v as Data: try v.encode(to: self)
        default: try value.encode(to: self)
        }
    }

    func encodeOptional<T>(_ value: T?) throws where T: XDREncodable {
        if let v = value {
            try self.encode(Int32(1))
            try v.encode(to: self)
        }
        else {
            try self.encode(Int32(0))
        }
    }

    fileprivate func append(_ data: Data) {
        self.data.append(data)
    }

    fileprivate func append<S>(_ data: S) where S: Sequence, S.Element == Data.Iterator.Element {
        self.data.append(contentsOf: data)
    }
}

public class XDRDecoder {
    public enum Errors: Error {
        case prematureEndOfData
        case stringDecodingFailed(Data)
    }

    private var data: Data
    private var cursor: Int = 0

    public static func decode<T>(_ type: T.Type, data: Data) throws -> T where T: XDRDecodable {
        let decoder = XDRDecoder(data: data)
        return try decoder.decode(type)
    }

    public func decode<T: XDRDecodable>(_ type: T.Type) throws -> T {
        return try type.init(from: self)
    }

    public func decodeArray<T: XDRDecodable>(_ type: T.Type) throws -> [T] {
        var a = [T]()

        let count = try decode(Int32.self)
        try (0 ..< count).forEach { _ in try a.append(type.init(from: self)) }
        return a
    }

    public init(data: Data) {
        self.data = data
    }

    public func read(_ count: Int) throws -> [UInt8] {
        guard cursor + count <= data.endIndex else { throw Errors.prematureEndOfData }

        defer { advance(by: count) }

        return data[cursor ..< cursor + count].array
    }

    fileprivate func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let byteCount = MemoryLayout<T>.size

        guard cursor + byteCount <= data.endIndex else { throw Errors.prematureEndOfData }

        defer { advance(by: byteCount) }

        return data[cursor ..< cursor + byteCount]
            .reduce(T(0), { $0 << 8 | T($1) })
    }

    fileprivate func advance(by count: Int) {
        cursor += count
    }
}

extension Bool: XDRCodable {
    public init(from decoder: XDRDecoder) throws {
        self = try decoder.decode(UInt32.self) > 0
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self ? UInt32(1) : UInt32(0))
    }
}

extension FixedWidthInteger where Self: XDRCodable {
    public init(from decoder: XDRDecoder) throws {
        self = try decoder.read(Self.self)
    }

    public func encode(to encoder: XDREncoder) throws {
        var v = self.bigEndian

        withUnsafeBytes(of: &v, encoder.append)
    }
}

extension UInt8: XDRCodable { }
extension Int32: XDRCodable { }
extension UInt32: XDRCodable { }
extension Int64: XDRCodable { }
extension UInt64: XDRCodable { }

extension String: XDRCodable {
    public init(from decoder: XDRDecoder) throws {
        let data = try decoder.decode(Data.self)
        
        guard let s = String(bytes: data, encoding: .utf8) else {
            throw XDRDecoder.Errors.stringDecodingFailed(data)
        }

        self = s
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self.data(using: .utf8)!)
    }
}

extension Data: XDRCodable {
    public init(from decoder: XDRDecoder) throws {
        let length = try Int32(from: decoder)
        self = try Data(decoder.read(Int(length)))

        try (0 ..< (4 - Int(count) % 4) % 4).forEach { _ in _ = try decoder.decode(UInt8.self) }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(Int32(count))
        encoder.append(self)
        encoder.append(Array<UInt8>(repeating: 0, count: (4 - Int(count) % 4) % 4))
    }
}

extension Array: XDREncodable {
    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(Int32(count))
        try forEach {
            if let e = $0 as? XDREncodable {
                try e.encode(to: encoder)
            }
        }
    }
}
