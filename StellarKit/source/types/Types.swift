//
//  Types.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

private func decodeData(from decoder: XDRDecoder, capacity: Int) throws -> Data {
    var d = Data(capacity: capacity)

    for _ in 0 ..< capacity {
        let decoded = try UInt8.init(from: decoder)
        d.append(decoded)
    }

    return d
}

struct WrappedData32: XDRCodable, Equatable {
    let wrapped: Data

    private let capacity = 32

    public func xdrEncode(to encoder: XDREncoder) throws {
        try wrapped.forEach { try $0.encode(to: encoder) }
    }

    public init(fromBinary decoder: XDRDecoder) throws {
        wrapped = try decodeData(from: decoder, capacity: capacity)
    }

    init(_ data: Data) {
        if data.count >= capacity {
            self.wrapped = data
        }
        else {
            var d = data
            d.append(Data(count: capacity - data.count))
            self.wrapped = d
        }
    }

    public static func ==(lhs: WrappedData32, rhs: WrappedData32) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }
}

struct WrappedData4: XDRCodable, Equatable {
    let wrapped: Data

    private let capacity = 4

    public func xdrEncode(to encoder: XDREncoder) throws {
        try wrapped.forEach { try $0.encode(to: encoder) }
    }

    public init(fromBinary decoder: XDRDecoder) throws {
        wrapped = try decodeData(from: decoder, capacity: capacity)
    }

    init(_ data: Data) {
        if data.count >= capacity {
            self.wrapped = data
        }
        else {
            var d = data
            d.append(Data(count: capacity - data.count))
            self.wrapped = d
        }
    }

    public static func ==(lhs: WrappedData4, rhs: WrappedData4) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }
}

struct WrappedData12: XDRCodable, Equatable {
    let wrapped: Data

    private let capacity = 12

    public func xdrEncode(to encoder: XDREncoder) throws {
        try wrapped.forEach { try $0.encode(to: encoder) }
    }

    public init(fromBinary decoder: XDRDecoder) throws {
        wrapped = try decodeData(from: decoder, capacity: capacity)
    }

    init(_ data: Data) {
        if data.count >= capacity {
            self.wrapped = data
        }
        else {
            var d = data
            d.append(Data(count: capacity - data.count))
            self.wrapped = d
        }
    }

    public static func ==(lhs: WrappedData12, rhs: WrappedData12) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }
}
