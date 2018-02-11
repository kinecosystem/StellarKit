//
//  StellarUtils.swift
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

private func networrkIdSHA256(_ networkId: String) throws -> Data {
    guard let sha256 = networkId.data(using: .utf8)?.sha256 else {
        throw StellarError.dataEncodingFailed
    }

    return sha256
}

func sign(transaction tx: Transaction,
          signer: Account,
          hint: Data,
          networkId: String) throws -> TransactionEnvelope {
    let sha256 = try networrkIdSHA256(networkId)

    let payload = TransactionSignaturePayload(networkId: WD32(sha256),
                                              taggedTransaction: .ENVELOPE_TYPE_TX(tx))

    let message = try Data(bytes: XDREncoder.encode(payload)).sha256

    guard let sign = signer.sign else {
        throw StellarError.missingSignClosure
    }

    let signature = try sign(message)

    return TransactionEnvelope(tx: tx,
                               signatures: [DecoratedSignature(hint: WrappedData4(hint),
                                                               signature: signature)])
}

func postTransaction(baseURL: URL, envelope: TransactionEnvelope) -> Promise<String> {
    let envelopeData: Data
    do {
        envelopeData = try Data(XDREncoder.encode(envelope))
    }
    catch {
        return Promise<String>(error)
    }

    guard let urlEncodedEnvelope = envelopeData.base64EncodedString().urlEncoded else {
        return Promise<String>(StellarError.urlEncodingFailed)
    }

    guard let httpBody = ("tx=" + urlEncodedEnvelope).data(using: .utf8) else {
        return Promise<String>(StellarError.dataEncodingFailed)
    }

    var request = URLRequest(url: baseURL.appendingPathComponent("transactions"))
    request.httpMethod = "POST"
    request.httpBody = httpBody

    return issue(request: request)
        .then { data in
            if let horizonError = try? JSONDecoder().decode(HorizonError.self, from: data),
                let resultXDR = horizonError.extras?.resultXDR,
                let error = errorFromResponse(resultXDR: resultXDR) {
                throw error
            }

            do {
                let txResponse = try JSONDecoder().decode(TransactionResponse.self,
                                                          from: data)

                return Promise<String>(txResponse.hash)
            }
            catch {
                throw error
            }
    }
}

func accountDetails(baseURL: URL, account: String) -> Promise<AccountDetails> {
    let url = baseURL.appendingPathComponent("accounts").appendingPathComponent(account)

    return issue(request: URLRequest(url: url))
        .then { data in
            if let horizonError = try? JSONDecoder().decode(HorizonError.self, from: data) {
                if horizonError.status == 404 {
                    throw StellarError.missingAccount
                }
                else {
                    throw StellarError.unknownError(horizonError)
                }
            }

            return try Promise<AccountDetails>(JSONDecoder().decode(AccountDetails.self, from: data))
    }
}

func issue(request: URLRequest) -> Promise<Data> {
    let p = Promise<Data>()

    URLSession
        .shared
        .dataTask(with: request, completionHandler: { (data, response, error) in
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
