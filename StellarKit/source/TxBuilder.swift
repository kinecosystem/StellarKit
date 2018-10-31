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

    public func set(memo: Memo) -> TxBuilder {
        self.memo = memo

        return self
    }

    public func set(fee: UInt32) -> TxBuilder {
        self.fee = fee

        return self
    }

    public func set(sequence: UInt64) -> TxBuilder {
        self.sequence = sequence

        return self
    }

    public func add(operation: Operation) -> TxBuilder {
        operations.append(operation)

        return self
    }

    public func add(operations: [Operation]) -> TxBuilder {
        self.operations += operations

        return self
    }

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

        if sequence > 0 {
            p.signal(Transaction(sourceAccount: pk,
                                 seqNum: sequence,
                                 timeBounds: nil,
                                 memo: memo ?? .MEMO_NONE,
                                 fee: fee,
                                 operations: operations))
        }
        else {
            Stellar.sequence(account: sourceKey, seqNum: sequence, node: node)
                .then {
                    let tx = Transaction(sourceAccount: pk,
                                         seqNum: $0,
                                         timeBounds: nil,
                                         memo: self.memo ?? .MEMO_NONE,
                                         operations: self.operations)

                    p.signal(tx)
                }
                .error { _ in
                    p.signal(StellarError.missingSequence)
            }
        }

        return p
    }

    public func envelope(networkId: String) -> Promise<TransactionEnvelope> {
        let p = Promise<TransactionEnvelope>()

        tx()
            .then({tx in
                do {
                    p.signal(try self.sign(tx: tx, networkId: networkId))
                }
                catch {
                    p.signal(error)
                }
            })

        return p
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
                return try DecoratedSignature(hint: hint, signature:sign(m))
                }())
        })

        return TransactionEnvelope(tx: tx, signatures: sigs)
    }
}
