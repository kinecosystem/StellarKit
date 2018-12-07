//
//  StellarResults.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

struct TransactionResultCode {
    static let txSUCCESS: Int32 = 0               // all operations succeeded

    static let txFAILED: Int32 = -1               // one of the operations failed (none were applied)

    static let txTOO_EARLY: Int32 = -2            // ledger closeTime before minTime
    static let txTOO_LATE: Int32 = -3             // ledger closeTime after maxTime
    static let txMISSING_OPERATION: Int32 = -4    // no operation was specified
    static let txBAD_SEQ: Int32 = -5              // sequence number does not match source account

    static let txBAD_AUTH: Int32 = -6             // too few valid signatures / wrong network
    static let txINSUFFICIENT_BALANCE: Int32 = -7 // fee would bring account below reserve
    static let txNO_ACCOUNT: Int32 = -8           // source account not found
    static let txINSUFFICIENT_FEE: Int32 = -9     // fee is too small
    static let txBAD_AUTH_EXTRA: Int32 = -10      // unused signatures attached to transaction
    static let txINTERNAL_ERROR: Int32 = -11      // an unknown error occured
}

public struct TransactionResult: XDRCodable, XDREncodableStruct {
    public let feeCharged: Int64
    public let result: Result
    public let reserved: Int32 = 0

    public enum Result: XDRCodable {
        case txSUCCESS([OperationResult])
        case txFAILED([OperationResult])
        case txTOO_EARLY
        case txTOO_LATE
        case txMISSING_OPERATION
        case txBAD_SEQ
        case txBAD_AUTH
        case txINSUFFICIENT_BALANCE
        case txNO_ACCOUNT
        case txINSUFFICIENT_FEE
        case txBAD_AUTH_EXTRA
        case txINTERNAL_ERROR

        public init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)

            switch discriminant {
            case TransactionResultCode.txSUCCESS:
                self = .txSUCCESS(try decoder.decodeArray(OperationResult.self))
            case TransactionResultCode.txFAILED:
                self = .txFAILED(try decoder.decodeArray(OperationResult.self))
            case TransactionResultCode.txTOO_EARLY:
                self = .txTOO_EARLY
            case TransactionResultCode.txTOO_LATE:
                self = .txTOO_LATE
            case TransactionResultCode.txMISSING_OPERATION:
                self = .txMISSING_OPERATION
            case TransactionResultCode.txBAD_SEQ:
                self = .txBAD_SEQ
            case TransactionResultCode.txBAD_AUTH:
                self = .txBAD_AUTH
            case TransactionResultCode.txINSUFFICIENT_BALANCE:
                self = .txINSUFFICIENT_BALANCE
            case TransactionResultCode.txNO_ACCOUNT:
                self = .txNO_ACCOUNT
            case TransactionResultCode.txINSUFFICIENT_FEE:
                self = .txINSUFFICIENT_FEE
            case TransactionResultCode.txBAD_AUTH_EXTRA:
                self = .txBAD_AUTH_EXTRA
            case TransactionResultCode.txINTERNAL_ERROR:
                self = .txINTERNAL_ERROR
            default:
                self = .txINTERNAL_ERROR
            }
        }

        private func discriminant() -> Int32 {
            switch self {
            case .txSUCCESS: return TransactionResultCode.txSUCCESS
            case .txFAILED: return TransactionResultCode.txFAILED
            case .txTOO_EARLY: return TransactionResultCode.txTOO_EARLY
            case .txTOO_LATE: return TransactionResultCode.txTOO_LATE
            case .txMISSING_OPERATION: return TransactionResultCode.txMISSING_OPERATION
            case .txBAD_SEQ: return TransactionResultCode.txBAD_SEQ
            case .txBAD_AUTH: return TransactionResultCode.txBAD_AUTH
            case .txINSUFFICIENT_BALANCE: return TransactionResultCode.txINSUFFICIENT_BALANCE
            case .txNO_ACCOUNT: return TransactionResultCode.txNO_ACCOUNT
            case .txINSUFFICIENT_FEE: return TransactionResultCode.txINSUFFICIENT_FEE
            case .txBAD_AUTH_EXTRA: return TransactionResultCode.txBAD_AUTH_EXTRA
            case .txINTERNAL_ERROR: return TransactionResultCode.txINTERNAL_ERROR
            }
        }

        public func encode(to encoder: XDREncoder) throws {
            try encoder.encode(discriminant())

            switch self {
            case .txSUCCESS(let ops): try encoder.encode(ops)
            case .txFAILED(let ops): try encoder.encode(ops)
            default:
                break
            }
        }
    }

    public init(from decoder: XDRDecoder) throws {
        feeCharged = try decoder.decode(Int64.self)
        result = try decoder.decode(Result.self)
        _ = try decoder.decode(Int32.self)
    }

    init(feeCharged: Int64, result: Result) {
        self.feeCharged = feeCharged
        self.result = result
    }
}

public extension TransactionResult {
    var operationResults: [OperationResult]? {
        if case let  Result.txSUCCESS(opResults) = result {
            return opResults
        }

        if case let  Result.txFAILED(opResults) = result {
            return opResults
        }

        return nil
    }
}

struct OperationResultCode {
    static let opINNER: Int32 = 0       // inner object result is valid

    static let opBAD_AUTH: Int32 = -1   // too few valid signatures / wrong network
    static let opNO_ACCOUNT: Int32 = -2 // source account was not found
}

public enum OperationResult: XDRCodable {
    case opINNER (Tr)
    case opBAD_AUTH
    case opNO_ACCOUNT

    // Add cases as necessary.
    public enum Tr: XDRCodable {
        case CREATE_ACCOUNT(CreateAccountResult)
        case CHANGE_TRUST(ChangeTrustResult)
        case PAYMENT(PaymentResult)
        case MANAGE_DATA(ManageDataResult)
        case unknown

        public init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)

            switch discriminant {
            case OperationType.PAYMENT:
                self = .PAYMENT(try decoder.decode(PaymentResult.self))
            case OperationType.CREATE_ACCOUNT:
                self = .CREATE_ACCOUNT(try decoder.decode(CreateAccountResult.self))
            case OperationType.CHANGE_TRUST:
                self = .CHANGE_TRUST(try decoder.decode(ChangeTrustResult.self))
            case OperationType.MANAGE_DATA:
                self = .MANAGE_DATA(try decoder.decode(ManageDataResult.self))
            default:
                self = .unknown
            }
        }

        private func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            default:
                return -1
            }
        }

        public func encode(to encoder: XDREncoder) throws {
            try encoder.encode(discriminant())

            switch self {
            case .CREATE_ACCOUNT(let result): try encoder.encode(result)
            case .PAYMENT(let result): try encoder.encode(result)
            default:
                break
            }
        }
    }

    public init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case OperationResultCode.opINNER:
            self = .opINNER(try decoder.decode(Tr.self))
        case OperationResultCode.opBAD_AUTH:
            self = .opBAD_AUTH
        case OperationResultCode.opNO_ACCOUNT:
            self = .opNO_ACCOUNT
        default:
            self = .opNO_ACCOUNT
        }
    }

    private func discriminant() -> Int32 {
        switch self {
        case .opINNER: return OperationResultCode.opINNER
        case .opBAD_AUTH: return OperationResultCode.opBAD_AUTH
        case .opNO_ACCOUNT: return OperationResultCode.opNO_ACCOUNT
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())

        switch self {
        case .opINNER(let tr): try encoder.encode(tr)
        case .opBAD_AUTH: break
        case .opNO_ACCOUNT: break
        }
    }
}

public extension OperationResult {
    var tr: Tr? {
        if case let OperationResult.opINNER(tr) = self {
            return tr
        }

        return nil
    }
}

public enum CreateAccountResult: Int32, XDRCodable {
    case success = 0
    case malformed = -1
    case underfunded = -2
    case lowReserve = -3
    case alreadyExists = -4

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self.rawValue)
    }

    public init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self.init(rawValue: value)!
    }
}

public enum ChangeTrustResult: Int32, XDRCodable {
    case success = 0
    case malformed = -1
    case noIssuer = -2
    case invalidLimit = -3
    case lowReserve = -4
    case selfNotAllowed = -5

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self.rawValue)
    }

    public init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self.init(rawValue: value)!
    }
}

public enum PaymentResult: Int32, XDRCodable {
    case success = 0
    case malformed = -1
    case underfunded = -2
    case srcNoTrust = -3
    case srcNotAuthorized = -4
    case noDestination = -5
    case noTrust = -6
    case notAuthorized = -7
    case lineFull = -8
    case noIssuer = -9

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self.rawValue)
    }

    public init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self.init(rawValue: value)!
    }
}

public enum ManageDataResult: Int32, XDRCodable {
    case success = 0
    case notSupportedYet = -1
    case nameNotFound = -2
    case lowReserve = -3
    case invalidName = -4

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(self.rawValue)
    }

    public init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self.init(rawValue: value)!
    }
}
