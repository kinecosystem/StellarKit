//
//  StellarUtils.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarErrors
import KinUtil

private func networkIdSHA256(_ networkId: String) throws -> Data {
    guard let sha256 = networkId.data(using: .utf8)?.sha256 else {
        throw StellarError.dataEncodingFailed
    }

    return sha256
}

func sign(transaction tx: Transaction,
          signer: Account,
          hint: Data,
          networkId: String) throws -> TransactionEnvelope {
    let sha256 = try networkIdSHA256(networkId)

    let payload = OperationSignaturePayload(networkId: WD32(sha256), operation: tx.operations[0])

    print("Moo: \(try! XDREncoder.encode(payload).hexString)")
    let message = try XDREncoder.encode(payload).sha256

    guard let sign = signer.sign else {
        throw StellarError.missingSignClosure
    }

    let opSig = try sign(message)

    let txPayload = TransactionSignaturePayload(networkId: WD32(sha256),
                                                taggedTransaction: .ENVELOPE_TYPE_TX(tx))

    let txMessage = try XDREncoder.encode(txPayload).sha256

    let txSig = try sign(txMessage)

    return TransactionEnvelope(tx: tx,
                               signatures: [
                                DecoratedSignature(hint: WrappedData4(hint), signature: opSig),
                                DecoratedSignature(hint: WrappedData4(hint), signature: txSig),
                                ])
}

func issue(request: URLRequest) -> Promise<Data> {
    let p = Promise<Data>()

    URLSession
        .shared
        .dataTask(with: request, completionHandler: { (data, _, error) in
            if let error = error {
                p.signal(error)

                return
            }

            guard let data = data else {
                p.signal(StellarError.internalInconsistency)

                return
            }

            p.signal(data)
        })
        .resume()

    return p
}
