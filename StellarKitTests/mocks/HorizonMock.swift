//
//  HorizonMock.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
@testable import StellarKit

class Balance {
    let asset: Asset
    var amount: UInt64

    init(asset: Asset, amount: UInt64 = 0) {
        self.asset = asset
        self.amount = amount
    }
}

class MockAccount {
    var balances = [Balance]()
    var sequence: UInt64 = 1

    init(balances: [Balance]) {
        self.balances = balances
    }

    func balance(for asset: Asset) -> Balance? {
        return balances.filter({ $0.asset == asset }).first
    }

    func asDictionary() -> [String: Any] {
        var d: [String: Any] = [:]

        d["sequence"] = String(describing: sequence)

        var b: [[String: String]] = []

        for balance in balances {
            var d = [
                "asset_code": balance.asset.assetCode,
                "balance": String(describing: balance.amount)
            ]

            if let issuer = balance.asset.issuer {
                d["asset_issuer"] = issuer
            }

            b.append(d)
        }

        d["balances"] = b

        return d
    }
}

class HorizonMock {
    var accounts = [String: MockAccount]()

    func inject(account: MockAccount, key: String) {
        accounts[key] = account
    }

    init() {
        HTTPMock.add(mock: accountMock())
        HTTPMock.add(mock: transactionMock())
    }

    deinit {
        HTTPMock.removeAll()
    }

    func accountMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard
                let key = mock.variables["account"],
                let account = self?.accounts[key] else {
                    return self?.missingAccount()
            }

            return try? JSONSerialization.data(withJSONObject: account.asDictionary(), options: [])
        }

        return RequestMock(host: "horizon",
                           path: "/accounts/${account}",
                           httpMethod: "GET",
                           mockHandler: handler)
    }

    func transactionMock() -> RequestMock {
        let handler: MockHandler = { [weak self] mock, request in
            guard let bodyString = self?.string(from: request.httpBodyStream) else {
                return self?.malformedTransaction()
            }

            let urlEncodedStr = bodyString.substring(fromIndex: 3)

            guard
                let base64Str = urlEncodedStr.removingPercentEncoding,
                let xdr = Data(base64Encoded: base64Str)
                else {
                    return self?.malformedTransaction()
            }

            let envelope: TransactionEnvelope

            do {
                envelope = try XDRDecoder.decode(TransactionEnvelope.self, data: xdr)
            }
            catch {
                return self?.malformedTransaction()
            }

            guard
                let publicKey = envelope.tx.sourceAccount.publicKey,
                let account = self?.accounts[publicKey] else {
                    return self?.missingSource()
            }

            guard let op = envelope.tx.operations.first else {
                return self?.missingOp()
            }

            account.balance(for: .ASSET_TYPE_NATIVE)?.amount -= UInt64(envelope.tx.fee)
            account.sequence += 1

            if case .PAYMENT(let paymentOp) = op.body {
                return self?.handle(paymentOp: paymentOp, source: account)
            }
            else if case .CREATE_ACCOUNT(let createOp) = op.body {
                return self?.handle(createAccountOp: createOp, source: account)
            }
            else if case .CHANGE_TRUST(let trustOp) = op.body {
                return self?.handle(trustOp: trustOp, source: account)
            }

            return nil
        }

        return RequestMock(host: "horizon",
                           path: "/transactions",
                           httpMethod: "POST",
                           mockHandler: handler)
    }

    func handle(paymentOp: PaymentOp, source account: MockAccount) -> Data? {
        guard
            let key = paymentOp.destination.publicKey,
            let dest = accounts[key] else {
                return missingDestination()
        }

        if let destBalance = dest.balance(for: paymentOp.asset) {
            if let sourceBalance = account.balance(for: paymentOp.asset) {
                if sourceBalance.amount < paymentOp.amount {
                    return insufficientFunds()
                }

                sourceBalance.amount -= UInt64(paymentOp.amount)
                destBalance.amount += UInt64(paymentOp.amount)
            }
        }
        else {
            return noTrust()
        }

        return paymentSuccess()
    }

    func handle(createAccountOp op: CreateAccountOp, source account: MockAccount) -> Data? {
        guard let key = op.destination.publicKey else {
            return missingDestination()
        }

        if accounts[key] != nil {
            return opAlreadyExists()
        }

        let account = MockAccount(balances: [Balance(asset: .ASSET_TYPE_NATIVE, amount: UInt64(op.balance))])
        accounts[key] = account

        return createAccountSuccess()
    }

    func handle(trustOp op: ChangeTrustOp, source account: MockAccount) -> Data? {
        if account.balance(for: op.asset) == nil {
            account.balances.append(Balance(asset: op.asset, amount: 0))
        }

        return createAccountSuccess()
    }

    private func missingAccount() -> Data {
        let d = [
            "type": "https://stellar.org/horizon-errors/not_found",
            "title": "Resource Missing",
            "status": "404",
            "detail": "Reasons",
            "instance": "horizon-mock",
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func malformedTransaction() -> Data {
        let d: [String: Any] = [
            "type": "https://stellar.org/horizon-errors/transaction_malformed",
            "title": "Transaction Malformed",
            "status": "400",
            "detail": "Reasons",
            "instance": "horizon-mock",
            "extras": [ "envelope_xdr": "-" ],
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func opAlreadyExists() -> Data {
        return failedTransaction(resultCode: "tx_failed",
                                 transactionResult: TransactionResult(feeCharged: 100, result: .txFAILED([OperationResult
                                    .opINNER(OperationResult.Tr
                                        .CREATE_ACCOUNT(CreateAccountResult.failure(CreateAccountResultCode.CREATE_ACCOUNT_ALREADY_EXIST)))])))
    }

    private func badSequence() -> Data {
        return failedTransaction(resultCode: "tx_bad_seq",
                                 transactionResult: TransactionResult(feeCharged: 100, result:
                                    .txERROR(TransactionResultCode.txBAD_SEQ)))
    }

    private func missingOp() -> Data {
        return failedTransaction(resultCode: "tx_missing_op",
                                 transactionResult: TransactionResult(feeCharged: 100, result:
                                    .txERROR(TransactionResultCode.txMISSING_OPERATION)))
    }

    private func missingSource() -> Data {
        return failedTransaction(resultCode: "tx_no_source_account",
                                 transactionResult: TransactionResult(feeCharged: 100, result:
                                    .txERROR(TransactionResultCode.txNO_ACCOUNT)))
    }

    private func missingDestination() -> Data {
        return failedTransaction(resultCode: "op_no_destination_account",
                                 transactionResult: TransactionResult(feeCharged: 100, result: .txFAILED([OperationResult
                                    .opINNER(OperationResult.Tr.PAYMENT(PaymentResult.failure(PaymentResultCode.PAYMENT_NO_DESTINATION)))])))
    }

    private func insufficientFunds() -> Data {
        return failedTransaction(resultCode: "op_no_destination_account",
                                 transactionResult: TransactionResult(feeCharged: 100, result: .txFAILED([OperationResult
                                    .opINNER(OperationResult.Tr.PAYMENT(PaymentResult.failure(PaymentResultCode.PAYMENT_UNDERFUNDED)))])))
    }

    private func noTrust() -> Data {
        return failedTransaction(resultCode: "op_no_destination_account",
                                 transactionResult: TransactionResult(feeCharged: 100, result: .txFAILED([OperationResult
                                    .opINNER(OperationResult.Tr.PAYMENT(PaymentResult.failure(PaymentResultCode.PAYMENT_NO_TRUST)))])))
    }

    private func failedTransaction(resultCode: String, transactionResult: TransactionResult) -> Data {
        let d: [String: Any] = [
            "type": "https://stellar.org/horizon-errors/transaction_failed",
            "title": "Transaction Failed",
            "status": "400",
            "detail": "Reasons",
            "instance": "horizon-mock",
            "extras": [
                "envelope_xdr": "-",
                "result_codes": [
                    "transaction": resultCode,
                ],
                "result_xdr": try! Data(bytes: XDREncoder.encode(transactionResult)).base64EncodedString()
            ],
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func paymentSuccess() -> Data {
        let d: [String: Any] = [
            "hash": "-",
            "ledger": 1,
            "result_xdr":
                try! Data(bytes: XDREncoder.encode(
                TransactionResult(feeCharged: 100,
                                            result: .txSUCCESS([OperationResult
                                                .opINNER(OperationResult.Tr
                                                    .PAYMENT(PaymentResult.success))]))))
                .base64EncodedString(),
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func createAccountSuccess() -> Data {
        let d: [String: Any] = [
            "hash": "-",
            "ledger": 1,
            "result_xdr":
                try! Data(bytes: XDREncoder.encode(
                    TransactionResult(feeCharged: 100,
                                            result: .txSUCCESS([OperationResult
                                                .opINNER(OperationResult.Tr
                                                    .CREATE_ACCOUNT(CreateAccountResult.success))]))))
                .base64EncodedString(),
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func changeTrustSuccess() -> Data {
        let d: [String: Any] = [
            "hash": "-",
            "ledger": 1,
            "result_xdr":
                try! Data(bytes: XDREncoder.encode(
                    TransactionResult(feeCharged: 100,
                                      result: .txSUCCESS([OperationResult
                                        .opINNER(OperationResult.Tr
                                            .CHANGE_TRUST(ChangeTrustResult.success))]))))
                .base64EncodedString(),
            ]

        return try! JSONSerialization.data(withJSONObject: d, options: [])
    }

    private func string(from: InputStream?) -> String? {
        guard let stream = from else {
            return nil
        }

        var data = Data()
        var buffer = Array<UInt8>(repeating: 0, count: 4096)

        stream.open()

        while stream.hasBytesAvailable {
            let length = stream.read(&buffer, maxLength: 4096)
            if length == 0 {
                break
            } else {
                data.append(&buffer, count: length)
            }
        }

        return String(bytes: data, encoding: .utf8)
    }
}
