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
    private var opSigners = [(Operation, Account)]()

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


    public func add(operation: Operation, signer: Account) -> TxBuilder {
        opSigners.append((operation, signer))

        return self
    }

    public func add(operations: [Operation]) -> TxBuilder {
        self.operations += operations

        return self
    }

    public func tx() -> Promise<Transaction> {
        let p = Promise<Transaction>()

        guard let sourceKey = source.publicKey else {
            p.signal(StellarError.missingPublicKey)

            return p
        }

        let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: sourceKey)))

        let operations = self.operations + opSigners.map({ $0.0 })

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
                                         operations: operations)

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

    private func networkIdSHA256(_ networkId: String) throws -> Data {
        guard let sha256 = networkId.data(using: .utf8)?.sha256 else {
            throw StellarError.dataEncodingFailed
        }

        return sha256
    }

    private func sign(tx: Transaction, networkId: String) throws -> TransactionEnvelope {
        var sigs = [DecoratedSignature]()

        let networkHash = try WD32(networkIdSHA256(networkId))

        try sigs.append({
            guard let sign = self.source.sign else {
                throw StellarError.missingSignClosure
            }

            guard let publicKey = self.source.publicKey else {
                throw StellarError.missingPublicKey
            }

            let p = TransactionSignaturePayload(networkId: networkHash,
                                                taggedTransaction: .ENVELOPE_TYPE_TX(tx))

            let m = try XDREncoder.encode(p).sha256

            let hint = WrappedData4(KeyUtils.key(base32: publicKey).suffix(4))
            return try DecoratedSignature(hint: hint, signature:sign(m))
            }())

        try opSigners.filter({ $0.1.publicKey != source.publicKey }).forEach({ (op, signer) in
            try sigs.append({
                guard let sign = signer.sign else {
                    throw StellarError.missingSignClosure
                }

                guard let publicKey = signer.publicKey else {
                    throw StellarError.missingPublicKey
                }

                let p = OperationSignaturePayload(networkId: networkHash, operation: op)

                let m = try XDREncoder.encode(p).sha256

                let hint = WrappedData4(KeyUtils.key(base32: publicKey).suffix(4))
                return try DecoratedSignature(hint: hint, signature:sign(m))
                }())
        })

        return TransactionEnvelope(tx: tx, signatures: sigs)
    }
}
