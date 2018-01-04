//
//  Stellar.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

class Stellar {
    static func payment(source: Data,
                        destination: Data,
                        amount: Int64,
                        signingKey: Data,
                        completion: @escaping (Data?) -> Void) {
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(source))
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(destination))

        let operation = SwiftyStellar
            .Operation(sourceAccount: nil,
                       body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                              asset: .ASSET_TYPE_NATIVE,
                                                              amount: amount)))

        let url = URL(string: "https://horizon-testnet.stellar.org/accounts/\(publicKeyToStellar(source))")!
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard
                let data = data,
                let json = try! JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let sequenceStr = json["sequence"] as? String,
                let sequence = UInt64(sequenceStr) else {
                    return
            }

            let tx = Transaction(sourceAccount: sourcePK,
                                 seqNum: sequence + 1,
                                 timeBounds: nil,
                                 memo: .MEMO_NONE,
                                 operations: [
                                    operation,
                                    ])

            let envelope = sign(transaction: tx, signingKey: signingKey, hint: source.suffix(4))

            var allowedQueryParamAndKey = NSMutableCharacterSet.urlQueryAllowed
            allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")

            var request = URLRequest(url: URL(string: "https://horizon-testnet.stellar.org/transactions")!)
            request.httpMethod = "POST"
            request.httpBody = ("tx=" + envelope.toXDR().base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey)!).data(using: .utf8)

            let post = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                completion(data)
            })

            post.resume()
        }

        task.resume()
    }

    static func sign(transaction tx: Transaction, signingKey: Data, hint: Data) -> TransactionEnvelope {
        let networkId = "Test SDF Network ; September 2015".data(using: .utf8)!.sha256

        let payload = TransactionSignaturePayload(networkId: FixedLengthDataWrapper(networkId),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(tx))

        let sodium = Sodium()
        let signature = sodium.sign.signature(message: payload.toXDR().sha256, secretKey: signingKey)!

        return TransactionEnvelope(tx: tx,
                                   signatures: [DecoratedSignature(hint: FixedLengthDataWrapper(hint),
                                                                   signature: signature)])
    }
}
