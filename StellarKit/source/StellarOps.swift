//
//  StellarOps.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

extension Operation {
    public static func createAccount(destination: String,
                                     balance: Int64,
                                     source: Account? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.CREATE_ACCOUNT(CreateAccountOp(destination: destPK,
                                                                             balance: balance)))
    }
    
    public static func payment(destination: String,
                               amount: Int64,
                               asset: Asset,
                               source: Account? = nil) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: destination)))

        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: asset,
                                                                amount: amount)))

    }

    public static func changeTrust(asset: Asset, limit: Int64 = .max, source: Account? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        let body = Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: asset, limit: limit))
        return Operation(sourceAccount: sourcePK, body: body)
    }

    public static func setOptions(signer address: String, source: String? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source {
            sourcePK = .PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: source)))
        }

        let signerKey = SignerKey.SIGNER_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: address)))
        let signer = Signer(key: signerKey)
        let body = Operation.Body.SET_OPTIONS(SetOptionsOp(signer: signer))
        return Operation(sourceAccount: sourcePK, body: body)
    }

    public static func setOptions(masterWeight: UInt32, source: Account? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        let body = Operation.Body.SET_OPTIONS(SetOptionsOp(masterWeight: masterWeight))
        return Operation(sourceAccount: sourcePK, body: body)
    }

    public static func manageData(key: String, value: Data?, source: Account? = nil) -> Operation {
        var sourcePK: PublicKey? = nil
        if let source = source, let pk = source.publicKey {
            sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: pk)))
        }

        return Operation(sourceAccount: sourcePK,
                         body: Operation.Body.MANAGE_DATA(ManageDataOp(dataName: key, dataValue: value)))
    }
}
