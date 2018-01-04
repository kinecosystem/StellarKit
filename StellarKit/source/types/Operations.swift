//
//  Operations.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct CreateAccountOp: XDREncodableStruct {
    let destination: PublicKey
    let balance: Int64
}

struct PaymentOp: XDREncodableStruct {
    let destination: PublicKey
    let asset: Asset
    let amount: Int64
}

struct ChangeTrustOp: XDREncodableStruct {
    let asset: Asset
    let limit: Int64 = Int64.max
}
