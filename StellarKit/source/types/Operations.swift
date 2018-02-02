//
//  Operations.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct CreateAccountOp: XDRCodable {
    let destination: PublicKey
    let balance: Int64

    init(destination: PublicKey, balance: Int64) {
        self.destination = destination
        self.balance = balance
    }
}

struct PaymentOp: XDRCodable {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64

    init(destination: PublicKey, asset: Asset, amount: Int64) {
        self.destination = destination
        self.asset = asset
        self.amount = amount
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(destination)
        try container.encode(asset)
        try container.encode(amount)
    }
}

struct ChangeTrustOp: XDRCodable {
    let asset: Asset
    let limit: Int64 = Int64.max

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        asset = try container.decode(Asset.self)
        _ = try container.decode(Int64.self)
    }

    init(asset: Asset) {
        self.asset = asset
    }
}
