//
//  Stellar.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

typealias Completion = (String?, Error?) -> Void

private struct Assets {
    static let KINAssetIssuer = "GBGFNADX2FTYVCLDCVFY5ZRTVEMS4LV6HKMWOY7XJKVXMBIWVDESCJW5"

    private static let kinAssetPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(Data(base32KeyToData(key: KINAssetIssuer))))

    static let KINAsset = Asset
        .ASSET_TYPE_CREDIT_ALPHANUM4(Asset
            .Alpha4(assetCode: FixedLengthDataWrapper("KIN\0".data(using: .utf8)!),
                    issuer: kinAssetPK))
}

class Stellar {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func payment(source: Data,
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
                let envelope = try self.txEnvelope(source: source,
                                                   sequence: sequence,
                                                   operation: self.paymentOp(destination: destination,
                                                                             amount: amount),
                                                   signingKey: signingKey)

                self.postTransaction(envelope: envelope, completion: completion)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func trustKIN(source: Data,
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
                let envelope = try self.txEnvelope(source: source,
                                                   sequence: sequence,
                                                   operation: self.trustOp(),
                                                   signingKey: signingKey)

                self.postTransaction(envelope: envelope, completion: completion)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func balance(account: Data, completion: @escaping (Decimal?, Error?) -> Void) {
        let base32 = publicKeyToBase32(account)
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(base32)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                guard let balances = json["balances"] as? [[String: Any]] else {
                    completion(nil, StellarError.missingBalance)

                    return
                }

                for balance in balances {
                    if balance["asset_code"] as? String == "KIN" &&
                        balance["asset_issuer"] as? String == Assets.KINAssetIssuer {
                        if let amountStr = balance["balance"] as? String, let amount = Decimal(string: amountStr) {
                            completion(amount, nil)

                            return
                        }
                    }
                }

                completion(nil, StellarError.missingBalance)
            })
            .resume()
    }

    private func sequence(account: Data, completion: @escaping (UInt64?, Error?) -> Void) {
        let base32 = publicKeyToBase32(account)
        let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(base32)

        URLSession
            .shared
            .dataTask(with: url, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                guard
                    let sequenceStr = json["sequence"] as? String,
                    let sequence = UInt64(sequenceStr) else {
                        completion(nil, StellarError.missingSequence)

                        return
                }

                completion(sequence, nil)
            })
            .resume()
    }

    private func postTransaction(envelope: TransactionEnvelope, completion: @escaping Completion) {
        guard let urlEncodedEnvelope = envelope.toXDR().base64EncodedString().urlEncoded else {
            completion(nil, StellarError.urlEncodingFailed)

            return
        }

        let url = baseURL.appendingPathComponent("transactions")

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
                if error != nil {
                    completion(nil, error)

                    return
                }

                guard
                    let d = data,
                    let jsonOpt = try? JSONSerialization.jsonObject(with: d,
                                                                    options: []) as? [String: Any],
                    let json = jsonOpt else {
                        completion(nil, StellarError.parseError(data))

                        return
                }

                if let resultError = errorFromResponse(response: json) {
                    completion(nil, resultError)

                    return
                }

                guard let hash = json["hash"] as? String else {
                    completion(nil, StellarError.missingHash)

                    return
                }

                completion(hash, nil)
            })
            .resume()
    }

    private func paymentOp(destination: Data, amount: Int64) -> Operation {
        let destPK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(destination))

        return Operation(sourceAccount: nil,
                         body: Operation.Body.PAYMENT(PaymentOp(destination: destPK,
                                                                asset: Assets.KINAsset,
                                                                amount: amount)))

    }

    private func trustOp() -> Operation {
        return Operation(sourceAccount: nil,
                         body: Operation.Body.CHANGE_TRUST(ChangeTrustOp(asset: Assets.KINAsset)))
    }

    private func txEnvelope(source: Data,
                            sequence: UInt64,
                            operation: Operation,
                            signingKey: Data) throws -> TransactionEnvelope {
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(source))

        let tx = Transaction(sourceAccount: sourcePK,
                             seqNum: sequence + 1,
                             timeBounds: nil,
                             memo: .MEMO_NONE,
                             operations: [
                                operation,
                                ])

        return try sign(transaction: tx, signingKey: signingKey, hint: source.suffix(4))
    }

    private func sign(transaction tx: Transaction,
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
