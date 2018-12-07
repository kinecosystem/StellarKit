//
// TxBuilder.swift
// StellarKit
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import KinUtil

public final class TxBuilder {
    private var _tx: Transaction;

    private let source: Account
    private let node: Node

    private var fee: UInt32?
    private var signers = [String: Account]()

    public init(source: Account, node: Node, tx: Transaction? = nil) {
        self.source = source
        self.node = node

        signers[source.publicKey] = source

        _tx = tx ?? Transaction(sourceAccount: source.publicKey,
                                seqNum: 0,
                                timeBounds: nil,
                                memo: .MEMO_NONE,
                                fee: 0,
                                operations: [])

        if tx != nil {
            _tx.sourceAccount = PublicKey(WD32(KeyUtils.key(base32: source.publicKey)))
        }
    }

    @discardableResult
    public func set(memo: Memo) -> TxBuilder {
        _tx.memo = memo

        return self
    }

    @discardableResult
    public func set(fee: UInt32?) -> TxBuilder {
        self.fee = fee

        if let fee = fee {
            _tx.fee = fee
        }

        return self
    }

    @discardableResult
    public func set(sequence: UInt64) -> TxBuilder {
        _tx.seqNum = sequence

        return self
    }

    @discardableResult
    public func set(lowerBounds: Date) -> TxBuilder {
        let lower = UInt64(lowerBounds.timeIntervalSince1970)
        let upper = _tx.timeBounds?.maxTime ?? 0

        _tx.timeBounds = TimeBounds(minTime: lower, maxTime: upper)

        return self
    }

    @discardableResult
    public func set(upperBounds: Date) -> TxBuilder {
        let lower = _tx.timeBounds?.minTime ?? 0
        let upper = UInt64(upperBounds.timeIntervalSince1970)

        _tx.timeBounds = TimeBounds(minTime: lower, maxTime: upper)

        return self
    }

    @discardableResult
    public func set(bounds: (Date, Date)) -> TxBuilder {
        let lower = UInt64(bounds.0.timeIntervalSince1970)
        let upper = UInt64(bounds.1.timeIntervalSince1970)

        _tx.timeBounds = TimeBounds(minTime: lower, maxTime: upper)

        return self
    }

    @discardableResult
    public func add(operation: Operation) -> TxBuilder {
        _tx.operations.append(operation)

        return self
    }

    @discardableResult
    public func add(operations: [Operation]) -> TxBuilder {
        _tx.operations += operations

        return self
    }

    @discardableResult
    public func add(signer: Account) -> TxBuilder {
        signers[signer.publicKey] = signer

        return self
    }

    public func tx() -> Promise<Transaction> {
        return source.sequence(seqNum: _tx.seqNum, node: node)
            .then {
                self._tx.seqNum = $0

                return self.calculatedFee()
                    .then { (fee) -> Transaction in self._tx.fee = fee; return self._tx }
            }
    }

    public func post() -> Promise<Responses.TransactionSuccess> {
        return envelope()
            .then ({
                return self.node.post(envelope: $0)
            })
    }

    public func envelope() -> Promise<TransactionEnvelope> {
        return tx().then {
            return try self.sign(tx: $0, networkId: String(describing: self.node.networkId))
        }
    }

    private func calculatedFee() -> Promise<UInt32> {
        if let fee = fee {
            return Promise(fee)
        }

        return node.networkConfiguration()
            .then ({ params in
                UInt32(self._tx.operations.count) * params.baseFee
            })
    }
    
    private func sign(tx: Transaction, networkId: String) throws -> TransactionEnvelope {
        var sigs = [DecoratedSignature]()

        let m = try tx.hash(networkId: networkId)

        try signers.forEach({ pk, signer in
            try sigs.append({
                guard let sign = signer.sign else {
                    throw StellarError.missingSignClosure
                }

                let hint = WrappedData4(KeyUtils.key(base32: pk).suffix(4))
                return try DecoratedSignature(hint: hint, signature: sign(m))
                }())
        })

        return TransactionEnvelope(tx: tx, signatures: sigs)
    }
}
