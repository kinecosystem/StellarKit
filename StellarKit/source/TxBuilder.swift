//
// TxBuilder.swift
// StellarKit
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil
import StellarErrors

public final class TxBuilder {
    private var source: Account
    private var memo: Memo?
    private var fee: UInt32?
    private var sequence: UInt64 = 0
    private var operations = [Operation]()
    private var opSigners = [Account]()

    private var node: Stellar.Node

    public init(source: Account, node: Stellar.Node) {
        self.source = source
        self.node = node
    }

    @discardableResult
    public func set(memo: Memo) -> TxBuilder {
        self.memo = memo

        return self
    }

    @discardableResult
    public func set(fee: UInt32?) -> TxBuilder {
        self.fee = fee

        return self
    }

    @discardableResult
    public func set(sequence: UInt64) -> TxBuilder {
        self.sequence = sequence

        return self
    }

    @discardableResult
    public func add(operation: Operation) -> TxBuilder {
        operations.append(operation)

        return self
    }

    @discardableResult
    public func add(operations: [Operation]) -> TxBuilder {
        self.operations += operations

        return self
    }

    @discardableResult
    public func add(signer: Account) -> TxBuilder {
        opSigners.append(signer)

        return self
    }

    public func tx() -> Promise<Transaction> {
        let p = Promise<Transaction>()

        guard let sourceKey = source.publicKey else {
            p.signal(StellarError.missingPublicKey)

            return p
        }

        let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceKey)))

        Stellar.sequence(account: sourceKey, seqNum: sequence, node: node)
            .then { sequence in
                self.calculatedFee()
                    .then({
                        p.signal(Transaction(sourceAccount: pk,
                                             seqNum: sequence,
                                             timeBounds: nil,
                                             memo: self.memo ?? .MEMO_NONE,
                                             fee: $0,
                                             operations: self.operations))
                    })
                    .error({ p.signal($0) })
            }
            .error { _ in
                p.signal(StellarError.missingSequence)
        }

        return p
    }

    public func envelope(networkId: String) -> Promise<TransactionEnvelope> {
        return
            tx()
                .then({
                    return Promise(try self.sign(tx: $0, networkId: networkId))
                })
    }

    private func calculatedFee() -> Promise<UInt32> {
        if let fee = fee {
            return Promise(fee)
        }

        return Stellar.networkParameters(node: node)
            .then ({ params in
                Promise(UInt32(self.operations.count) * params.baseFee)
            })
    }
    
    private func sign(tx: Transaction, networkId: String) throws -> TransactionEnvelope {
        var sigs = [DecoratedSignature]()

        let m = try tx.hash(networkId: networkId)

        var signatories = opSigners
        signatories.append(source)

        try signatories.forEach({ signer in
            try sigs.append({
                guard let sign = signer.sign else {
                    throw StellarError.missingSignClosure
                }

                guard let publicKey = signer.publicKey else {
                    throw StellarError.missingPublicKey
                }

                let hint = WrappedData4(KeyUtils.key(base32: publicKey).suffix(4))
                return try DecoratedSignature(hint: hint, signature: sign(Array(m)))
                }())
        })

        return TransactionEnvelope(tx: tx, signatures: sigs)
    }
}
