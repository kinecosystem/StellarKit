//
//  Operations.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct CreateAccountOp: XDREncodableStruct, XDRDecodable {
    let destination: PublicKey
    let balance: Int64

    init(destination: PublicKey, balance: Int64) {
        self.destination = destination
        self.balance = balance
    }

    init(xdrData: inout Data, count: Int32 = 0) {
        destination = PublicKey(xdrData: &xdrData)
        balance = Int64(xdrData: &xdrData)
    }
}

struct PaymentOp: XDREncodableStruct, XDRDecodable {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64

    init(destination: PublicKey, asset: Asset, amount: Int64) {
        self.destination = destination
        self.asset = asset
        self.amount = amount
    }

    init(xdrData: inout Data, count: Int32 = 0) {
        destination = PublicKey(xdrData: &xdrData)
        asset = Asset(xdrData: &xdrData)
        amount = Int64(xdrData: &xdrData)
    }
}

struct ChangeTrustOp: XDREncodableStruct, XDRDecodable {
    let asset: Asset
    let limit: Int64 = Int64.max

    init(asset: Asset) {
        self.asset = asset
    }

    init(xdrData: inout Data, count: Int32 = 0) {
        asset = Asset(xdrData: &xdrData)
        _ = Int64(xdrData: &xdrData)
    }
}
