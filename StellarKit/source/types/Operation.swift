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

public struct Operation: XDREncodableStruct, XDRDecodable {
    let sourceAccount: PublicKey?
    let body: Body

    init(sourceAccount: PublicKey?, body: Body) {
        self.sourceAccount = sourceAccount
        self.body = body
    }

    public init(xdrData: inout Data, count: Int32 = 0) {
        sourceAccount = Array<PublicKey>(xdrData: &xdrData).first
        body = Body(xdrData: &xdrData)
    }

    enum Body: XDRCodable {
        case CREATE_ACCOUNT (CreateAccountOp)
        case PAYMENT (PaymentOp)
        case CHANGE_TRUST (ChangeTrustOp)

        init(xdrData: inout Data, count: Int32 = 0) {
            let discriminant = Int32(xdrData: &xdrData)

            switch discriminant {
            case OperationType.CREATE_ACCOUNT:
                self = .CREATE_ACCOUNT(CreateAccountOp(xdrData: &xdrData))
            case OperationType.CHANGE_TRUST:
                self = .CHANGE_TRUST(ChangeTrustOp(xdrData: &xdrData))
            case OperationType.PAYMENT:
                self = .PAYMENT(PaymentOp(xdrData: &xdrData))
            default:
                self = .CREATE_ACCOUNT(CreateAccountOp(xdrData: &xdrData))
            }
        }
        
        private func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            case .CHANGE_TRUST: return OperationType.CHANGE_TRUST
            }
        }

        func toXDR(count: Int32 = 0) -> Data {
            var xdr = discriminant().toXDR()

            switch self {
            case .CREATE_ACCOUNT (let op):
                xdr.append(op.toXDR())

            case .PAYMENT (let op):
                xdr.append(op.toXDR())

            case .CHANGE_TRUST (let op):
                xdr.append(op.toXDR())
            }

            return xdr
        }
    }
}

