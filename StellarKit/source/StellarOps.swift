//
//  StellarOps.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

extension Operation {
    private static func sourceKey(from source: Account?) -> PublicKey? {
        guard let source = source  else { return nil }

        return PublicKey(WD32(KeyUtils.key(base32: source.publicKey)))
    }

    public static func createAccount(destination: String,
                                     balance: Int64,
                                     source: Account? = nil) -> Operation {
        let destPK = PublicKey(WD32(KeyUtils.key(base32: destination)))

        return Operation(sourceAccount: sourceKey(from: source),
                         body: Operation.Body.CREATE_ACCOUNT(CreateAccountOp(destination: destPK,
                                                                             balance: balance)))
    }
    
    public static func payment(destination: String,
                               amount: Int64,
                               asset: Asset,
                               source: Account? = nil) -> Operation {
        let destPK = PublicKey(WD32(KeyUtils.key(base32: destination)))

        return Operation(sourceAccount: sourceKey(from: source),
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: asset,
                                                                amount: amount)))

    }

    public static func changeTrust(asset: Asset, source: Account? = nil) -> Operation {
        return Operation(sourceAccount: sourceKey(from: source),
                         body: Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: asset)))
    }

    public static func manageData(key: String, value: Data?, source: Account? = nil) -> Operation {
        return Operation(sourceAccount: sourceKey(from: source),
                         body: Operation.Body.MANAGE_DATA(ManageDataOp(dataName: key, dataValue: value)))
    }
}
