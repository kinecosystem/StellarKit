//
//  Stellar.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

enum StellarError: Error {
    case missingSequence
    case urlEncodingFailed
    case urlCreationFailed
    case dataEncodingFailed
    case signingFailed
}

typealias Completion = (Data?, Error?) -> Void

class Stellar {
    static func payment(source: Data,
                        destination: Data,
                        amount: Int64,
                        signingKey: Data,
                        completion: @escaping Completion) {
        sequence(account: source) { sequence, error in
            guard error == nil else {
                completion(nil, error)

                return
            }

            guard let sequence = sequence else {
                completion(nil, StellarError.missingSequence)

                return
            }

            do {
                let envelope = try txEnvelope(source: source,
                                              destination: destination,
                                              sequence: sequence,
                                              amount: amount,
                                              signingKey: signingKey)

                postTransaction(envelope: envelope, completion: completion)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    private static func sequence(account: Data, completion: @escaping (UInt64?, Error?) -> Void) {
        let base32 = publicKeyToStellar(account)
        guard let url = URL(string: "https://horizon-testnet.stellar.org/accounts/\(base32)") else {
            completion(nil, StellarError.urlCreationFailed)

            return
        }

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let data = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: data,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt,
                    let sequenceStr = json["sequence"] as? String,
                    let sequence = UInt64(sequenceStr) else {
                        completion(nil, StellarError.missingSequence)

                        return
                }

                completion(sequence, nil)
            })
            .resume()
    }

    private static func postTransaction(envelope: TransactionEnvelope, completion: @escaping Completion) {
        guard let urlEncodedEnvelope = envelope.toXDR().base64EncodedString().urlEncoded else {
            completion(nil, StellarError.urlEncodingFailed)

            return
        }

        guard let url = URL(string: "https://horizon-testnet.stellar.org/transactions") else {
            completion(nil, StellarError.urlCreationFailed)

            return
        }

        guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
            completion(nil, StellarError.dataEncodingFailed)

            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody

        URLSession
            .shared
            .dataTask(with: request, completionHandler: { data, response, error in
                completion(data, error)
            })
            .resume()
    }

    private static func txEnvelope(source: Data,
                                   destination: Data,
                                   sequence: UInt64,
                                   amount: Int64,
                                   signingKey: Data) throws -> TransactionEnvelope {
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(source))
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(destination))

        let operation = SwiftyStellar
            .Operation(sourceAccount: nil,
                       body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                              asset: .ASSET_TYPE_NATIVE,
                                                              amount: amount)))

        let tx = Transaction(sourceAccount: sourcePK,
                             seqNum: sequence + 1,
                             timeBounds: nil,
                             memo: .MEMO_NONE,
                             operations: [
                                operation,
                                ])

        return try sign(transaction: tx, signingKey: signingKey, hint: source.suffix(4))
    }

    private static func sign(transaction tx: Transaction,
                             signingKey: Data,
                             hint: Data) throws -> TransactionEnvelope {
        guard let data = "Test SDF Network ; September 2015".data(using: .utf8) else {
            throw StellarError.dataEncodingFailed
        }

        let networkId = data.sha256

        let payload = TransactionSignaturePayload(networkId: FixedLengthDataWrapper(networkId),
                                                  taggedTransaction: .ENVELOPE_TYPE_TX(tx))

        let sodium = Sodium()

        let message = payload.toXDR().sha256
        guard let signature = sodium.sign.signature(message: message, secretKey: signingKey) else {
            throw StellarError.signingFailed
        }

        return TransactionEnvelope(tx: tx,
                                   signatures: [DecoratedSignature(hint: FixedLengthDataWrapper(hint),
                                                                   signature: signature)])
    }
}
