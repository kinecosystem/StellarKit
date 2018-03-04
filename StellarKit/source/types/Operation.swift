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
        case PATH_PAYMENT (PathPaymentOp)
        case MANAGE_OFFER (ManageOfferOp)
        case CREATE_PASSIVE_OFFER (CreatePassiveOfferOp)
        case SET_OPTIONS (SetOptionsOp)
        case CHANGE_TRUST (ChangeTrustOp)
        case ALLOW_TRUST (AllowTrustOp)
        case ACCOUNT_MERGE (AccountMergeOp)
        case INFLATION
        case MANAGE_DATA (ManageDataOp)

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let discriminant = try container.decode(Int32.self)

            switch discriminant {
            case OperationType.CREATE_ACCOUNT:
                self = .CREATE_ACCOUNT(try container.decode(CreateAccountOp.self))
            case OperationType.PAYMENT:
                self = .PAYMENT(try container.decode(PaymentOp.self))
            case OperationType.PATH_PAYMENT:
                self = .PATH_PAYMENT(try container.decode(PathPaymentOp.self))
            case OperationType.MANAGE_OFFER:
                self = .MANAGE_OFFER(try container.decode(ManageOfferOp.self))
            case OperationType.CREATE_PASSIVE_OFFER:
                self = .CREATE_PASSIVE_OFFER(try container.decode(CreatePassiveOfferOp.self))
            case OperationType.CHANGE_TRUST:
                self = .CHANGE_TRUST(try container.decode(ChangeTrustOp.self))
            case OperationType.ALLOW_TRUST:
                self = .ALLOW_TRUST(try container.decode(AllowTrustOp.self))
            case OperationType.SET_OPTIONS:
                self = .SET_OPTIONS(try container.decode(SetOptionsOp.self))
            case OperationType.ACCOUNT_MERGE:
                self = .ACCOUNT_MERGE(try container.decode(AccountMergeOp.self))
            case OperationType.INFLATION:
                self = .INFLATION
            case OperationType.MANAGE_DATA:
                self = .MANAGE_DATA(try container.decode(ManageDataOp.self))
            default:
                fatalError("Invalid Op specified: \(discriminant)")
            }
        }

        private func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            case .PATH_PAYMENT: return OperationType.PATH_PAYMENT
            case .MANAGE_OFFER: return OperationType.MANAGE_OFFER
            case .CREATE_PASSIVE_OFFER: return OperationType.CREATE_PASSIVE_OFFER
            case .CHANGE_TRUST: return OperationType.CHANGE_TRUST
            case .ALLOW_TRUST: return OperationType.ALLOW_TRUST
            case .SET_OPTIONS: return OperationType.SET_OPTIONS
            case .ACCOUNT_MERGE: return OperationType.ACCOUNT_MERGE
            case .INFLATION: return OperationType.INFLATION
            case .MANAGE_DATA: return OperationType.MANAGE_DATA
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

            case .PATH_PAYMENT (let op):
                try container.encode(op)

            case .MANAGE_OFFER(let op):
                try container.encode(op)

            case .CREATE_PASSIVE_OFFER(let op):
                try container.encode(op)

            case .CHANGE_TRUST (let op):
                try container.encode(op)

            case .ALLOW_TRUST (let op):
                try container.encode(op)

            case .SET_OPTIONS (let op):
                try container.encode(op)

            case .ACCOUNT_MERGE(let op):
                try container.encode(op)

            case .INFLATION:
                break

            case .MANAGE_DATA(let op):
                try container.encode(op)
            }
        }
    }
}

