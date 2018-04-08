//
//  WrappedData.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

typealias WD4 = WrappedData32
typealias WD12 = WrappedData32
typealias WD32 = WrappedData32

private func decodeData(from decoder: XDRDecoder, capacity: Int) throws -> Data {
    var d = Data(capacity: capacity)

    for _ in 0 ..< capacity {
        let decoded = try UInt8.init(from: decoder)
        d.append(decoded)
    }

    return d
}

protocol WrappedData: XDRCodable, Equatable {
    static var capacity: Int { get }

    var wrapped: Data { get set }

    func encode(to encoder: XDREncoder) throws

    init()
    init(_ data: Data)
}

extension WrappedData {
    func encode(to encoder: XDREncoder) throws {
        try wrapped.forEach { try $0.encode(to: encoder) }
    }

    init(from decoder: XDRDecoder) throws {
        self.init()
        wrapped = try decodeData(from: decoder, capacity: Self.capacity)
    }

    init(_ data: Data) {
        self.init()

        if data.count >= Self.capacity {
            self.wrapped = data
        }
        else {
            var d = data
            d.append(Data(count: Self.capacity - data.count))
            self.wrapped = d
        }
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }
}

struct WrappedData4: WrappedData {
    static let capacity: Int = 4

    var wrapped: Data

    init() {
        wrapped = Data()
    }
}

struct WrappedData12: WrappedData {
    static let capacity: Int = 12

    var wrapped: Data

    init() {
        wrapped = Data()
    }
}

struct WrappedData32: WrappedData, Equatable {
    static let capacity: Int = 32

    var wrapped: Data

    init() {
        wrapped = Data()
    }
}
