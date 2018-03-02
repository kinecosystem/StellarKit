//
//  Operation.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct OperationType {
    static let CREATE_ACCOUNT: Int32 = 0
    static let PAYMENT: Int32 = 1
    static let PATH_PAYMENT: Int32 = 2
    static let MANAGE_OFFER: Int32 = 3
    static let CREATE_PASSIVE_OFFER: Int32 = 4
    static let SET_OPTIONS: Int32 = 5
    static let CHANGE_TRUST: Int32 = 6
    static let ALLOW_TRUST: Int32 = 7
    static let ACCOUNT_MERGE: Int32 = 8
    static let INFLATION: Int32 = 9
    static let MANAGE_DATA: Int32 = 10
}

public struct Operation: XDRCodable {
    let sourceAccount: PublicKey?
    let body: Body

    init(sourceAccount: PublicKey?, body: Body) {
        self.sourceAccount = sourceAccount
        self.body = body
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        sourceAccount = try container.decode(Array<PublicKey>.self).first
        body = try container.decode(Body.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(sourceAccount)
        try container.encode(body)
    }

    enum Body: XDRCodable {
        case CREATE_ACCOUNT (CreateAccountOp)
        case PAYMENT (PaymentOp)
        case CHANGE_TRUST (ChangeTrustOp)
        case MANAGE_OFFER (ManageOfferOp)
        case SET_OPTIONS (SetOptionsOp)
        case ACCOUNT_MERGE (AccountMergeOp)

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let discriminant = try container.decode(Int32.self)

            switch discriminant {
            case OperationType.CREATE_ACCOUNT:
                self = .CREATE_ACCOUNT(try container.decode(CreateAccountOp.self))
            case OperationType.CHANGE_TRUST:
                self = .CHANGE_TRUST(try container.decode(ChangeTrustOp.self))
            case OperationType.PAYMENT:
                self = .PAYMENT(try container.decode(PaymentOp.self))
            case OperationType.SET_OPTIONS:
                self = .SET_OPTIONS(try container.decode(SetOptionsOp.self))
            case OperationType.MANAGE_OFFER:
                self = .MANAGE_OFFER(try container.decode(ManageOfferOp.self))
            case OperationType.ACCOUNT_MERGE:
                self = .ACCOUNT_MERGE(try container.decode(AccountMergeOp.self))
            default:
                self = .CREATE_ACCOUNT(try container.decode(CreateAccountOp.self))
            }
        }
        
        private func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            case .CHANGE_TRUST: return OperationType.CHANGE_TRUST
            case .SET_OPTIONS: return OperationType.SET_OPTIONS
            case .MANAGE_OFFER: return OperationType.MANAGE_OFFER
            case .ACCOUNT_MERGE: return OperationType.ACCOUNT_MERGE
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(discriminant())

            switch self {
            case .CREATE_ACCOUNT (let op):
                try container.encode(op)

            case .PAYMENT (let op):
                try container.encode(op)

            case .CHANGE_TRUST (let op):
                try container.encode(op)

            case .SET_OPTIONS (let op):
                try container.encode(op)

            case .MANAGE_OFFER(let op):
                try container.encode(op)

            case .ACCOUNT_MERGE(let op):
                try container.encode(op)
            }
        }
    }
}

