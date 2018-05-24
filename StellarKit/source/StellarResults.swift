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

struct TransactionResult: XDRCodable, XDREncodableStruct {
    let feeCharged: Int64
    let result: Result
    let reserved: Int32 = 0

    enum Result: XDRCodable {
        case txSUCCESS ([OperationResult])
        case txFAILED ([OperationResult])
        case txERROR (Int32)

        init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)

            switch discriminant {
            case TransactionResultCode.txSUCCESS:
                self = .txSUCCESS(try decoder.decodeArray(OperationResult.self))
            case TransactionResultCode.txFAILED:
                self = .txFAILED(try decoder.decodeArray(OperationResult.self))
            default:
                self = .txERROR(discriminant)
            }
        }

        private func discriminant() -> Int32 {
            switch self {
            case .txSUCCESS: return TransactionResultCode.txSUCCESS
            case .txFAILED: return TransactionResultCode.txFAILED
            case .txERROR (let code): return code
            }
        }

        public func encode(to encoder: XDREncoder) throws {
            try encoder.encode(discriminant())

            switch self {
            case .txSUCCESS (let ops):
                try encoder.encode(ops)

            case .txFAILED (let ops):
                try encoder.encode(ops)

            case .txERROR (let code):
                try encoder.encode(code)
            }
        }
    }

    init(from decoder: XDRDecoder) throws {
        feeCharged = try decoder.decode(Int64.self)
        result = try decoder.decode(Result.self)
        _ = try decoder.decode(Int32.self)
    }

    init(feeCharged: Int64, result: Result) {
        self.feeCharged = feeCharged
        self.result = result
    }
}

struct OperationResultCode {
    static let opINNER: Int32 = 0       // inner object result is valid

    static let opBAD_AUTH: Int32 = -1   // too few valid signatures / wrong network
    static let opNO_ACCOUNT: Int32 = -2 // source account was not found
}

enum OperationResult: XDRCodable {
    case opINNER (Tr)
    case opBAD_AUTH
    case opNO_ACCOUNT

    // Add cases as necessary.
    enum Tr: XDRCodable {
        case CREATE_ACCOUNT (CreateAccountResult)
        case CHANGE_TRUST (ChangeTrustResult)
        case PAYMENT (PaymentResult)
        case MANAGE_OFFER (ManageOfferResult)
        case unknown

        init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)

            switch discriminant {
            case OperationType.PAYMENT:
                self = .PAYMENT(try decoder.decode(PaymentResult.self))
            case OperationType.CREATE_ACCOUNT:
                self = .CREATE_ACCOUNT(try decoder.decode(CreateAccountResult.self))
            case OperationType.CHANGE_TRUST:
                self = .CHANGE_TRUST(try decoder.decode(ChangeTrustResult.self))
            case OperationType.MANAGE_OFFER:
                self = .MANAGE_OFFER(try decoder.decode(ManageOfferResult.self))
            default:
                self = .unknown
            }
        }

        private func discriminant() -> Int32 {
            switch self {
            case .CREATE_ACCOUNT: return OperationType.CREATE_ACCOUNT
            case .PAYMENT: return OperationType.PAYMENT
            default: return -1
            }
        }

        func encode(to encoder: XDREncoder) throws {
            try encoder.encode(discriminant())

            switch self {
            case .CREATE_ACCOUNT (let result):
                try encoder.encode(result)
            case .PAYMENT (let result):
                try encoder.encode(result)
            default:
                break
            }
        }
    }

    init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)

        switch discriminant {
        case OperationResultCode.opINNER:
            self = .opINNER(try decoder.decode(Tr.self))
        case OperationResultCode.opBAD_AUTH:
            self = .opBAD_AUTH
        case OperationResultCode.opNO_ACCOUNT:
            fallthrough
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

    func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())

        switch self {
        case .opINNER (let tr):
            try encoder.encode(tr)
        case .opBAD_AUTH:
            break
        case .opNO_ACCOUNT:
            break
        }
    }
}

struct CreateAccountResultCode {
    static let CREATE_ACCOUNT_SUCCESS: Int32 = 0        // account was created

    static let CREATE_ACCOUNT_MALFORMED: Int32 = -1     // invalid destination
    static let CREATE_ACCOUNT_UNDERFUNDED: Int32 = -2   // not enough funds in source account
    static let CREATE_ACCOUNT_LOW_RESERVE: Int32 = -3   // would create an account below the min reserve
    static let CREATE_ACCOUNT_ALREADY_EXIST: Int32 = -4 // account already exists
}

enum CreateAccountResult: XDRCodable {
    case success
    case failure (Int32)

    private func discriminant() -> Int32 {
        switch self {
        case .success:
            return CreateAccountResultCode.CREATE_ACCOUNT_SUCCESS
        case .failure (let code):
            return code
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())
    }

    init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self = value == 0 ? .success : .failure(value)
    }
}

struct ChangeTrustResultCode {
    static let CHANGE_TRUST_SUCCESS: Int32 = 0

    static let CHANGE_TRUST_MALFORMED: Int32 = -1           // bad input
    static let CHANGE_TRUST_NO_ISSUER: Int32 = -2           // could not find issuer
    static let CHANGE_TRUST_INVALID_LIMIT: Int32 = -3       // cannot drop limit below balance
    static let CHANGE_TRUST_LOW_RESERVE: Int32 = -4         // not enough funds to create a new trust line,
    static let CHANGE_TRUST_SELF_NOT_ALLOWED: Int32 = -5    // trusting self is not allowed
};

enum ChangeTrustResult: XDRCodable {
    case success
    case failure (Int32)

    private func discriminant() -> Int32 {
        switch self {
        case .success:
            return ChangeTrustResultCode.CHANGE_TRUST_SUCCESS
        case .failure (let code):
            return code
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())
    }

    init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self = value == 0 ? .success : .failure(value)
    }
}

struct PaymentResultCode {
    // codes considered as "success" for the operation
    static let PAYMENT_SUCCESS: Int32 = 0 // payment successfuly completed

    // codes considered as "failure" for the operation
    static let PAYMENT_MALFORMED: Int32 = -1          // bad input
    static let PAYMENT_UNDERFUNDED: Int32 = -2        // not enough funds in source account
    static let PAYMENT_SRC_NO_TRUST: Int32 = -3       // no trust line on source account
    static let PAYMENT_SRC_NOT_AUTHORIZED: Int32 = -4 // source not authorized to transfer
    static let PAYMENT_NO_DESTINATION: Int32 = -5     // destination account does not exist
    static let PAYMENT_NO_TRUST: Int32 = -6           // destination missing a trust line for asset
    static let PAYMENT_NOT_AUTHORIZED: Int32 = -7     // destination not authorized to hold asset
    static let PAYMENT_LINE_FULL: Int32 = -8          // destination would go above their limit
    static let PAYMENT_NO_ISSUER: Int32 = -9          // missing issuer on asset
}

enum PaymentResult: XDRCodable {
    case success
    case failure (Int32)

    private func discriminant() -> Int32 {
        switch self {
        case .success:
            return PaymentResultCode.PAYMENT_SUCCESS
        case .failure (let code):
            return code
        }
    }

    public func encode(to encoder: XDREncoder) throws {
        try encoder.encode(discriminant())
    }

    init(from decoder: XDRDecoder) throws {
        let value = try decoder.decode(Int32.self)

        self = value == 0 ? .success : .failure(value)
    }
}

struct ManageOfferResultCode {
        // codes considered as "success" for the operation
    static let MANAGE_OFFER_SUCCESS: Int32 = 0
        
        // codes considered as "failure" for the operation
        static let MANAGE_OFFER_MALFORMED: Int32 = -1     // generated offer would be invalid
        static let MANAGE_OFFER_SELL_NO_TRUST: Int32 = -2 // no trust line for what we're selling
        static let MANAGE_OFFER_BUY_NO_TRUST: Int32 = -3  // no trust line for what we're buying
        static let MANAGE_OFFER_SELL_NOT_AUTHORIZED: Int32 = -4 // not authorized to sell
        static let MANAGE_OFFER_BUY_NOT_AUTHORIZED: Int32 = -5  // not authorized to buy
        static let MANAGE_OFFER_LINE_FULL: Int32 = -6      // can't receive more of what it's buying
        static let MANAGE_OFFER_UNDERFUNDED: Int32 = -7    // doesn't hold what it's trying to sell
        static let MANAGE_OFFER_CROSS_SELF: Int32 = -8     // would cross an offer from the same user
        static let MANAGE_OFFER_SELL_NO_ISSUER: Int32 = -9 // no issuer for what we're selling
        static let MANAGE_OFFER_BUY_NO_ISSUER: Int32 = -10 // no issuer for what we're buying
        
        // update errors
        static let MANAGE_OFFER_NOT_FOUND: Int32 = -11 // offerID does not match an existing offer
        
        static let MANAGE_OFFER_LOW_RESERVE: Int32 = -12 // not enough funds to create a new Offer
}

struct ClaimOfferAtom: XDRDecodable {
    init(from decoder: XDRDecoder) throws {
        sellerID = try decoder.decode(AccountID.self)
        offerID = try decoder.decode(UInt64.self)
        assetSold = try decoder.decode(Asset.self)
        amountSold = try decoder.decode(Int64.self)
        assetBought = try decoder.decode(Asset.self)
        amountBought = try decoder.decode(Int64.self)
    }
    
    let sellerID: AccountID
    let offerID: UInt64
    let assetSold: Asset
    let amountSold: Int64
    let assetBought: Asset
    let amountBought: Int64
}

struct ManageOfferSuccessResult: XDRDecodable {
    init(from decoder: XDRDecoder) throws {
        offersClaimed = try decoder.decodeArray(ClaimOfferAtom.self)
        effect = try decoder.decode(ManageOfferEffect.self)
    }
    
    let offersClaimed: [ClaimOfferAtom]
    let effect: ManageOfferEffect
    
    enum ManageOfferEffect: XDRDecodable {
        struct ManageOfferEffect
        {
            static let MANAGE_OFFER_CREATED: Int32 = 0
            static let MANAGE_OFFER_UPDATED: Int32 = 1
            static let MANAGE_OFFER_DELETED: Int32 = 2
        }

        init(from decoder: XDRDecoder) throws {
            let discriminant = try decoder.decode(Int32.self)
            
            switch discriminant {
            case ManageOfferEffect.MANAGE_OFFER_CREATED:
                self = .MANAGE_OFFER_CREATED(try decoder.decode(OfferEntry.self))
            default:
                self = .MANAGE_OFFER_UPDATED(try decoder.decode(OfferEntry.self))
            }
        }
        
        case MANAGE_OFFER_CREATED (OfferEntry)
        case MANAGE_OFFER_UPDATED (OfferEntry)
    }
}

enum ManageOfferResult: XDRDecodable {
    case MANAGE_OFFER_SUCCESS (ManageOfferSuccessResult)
    case failure (Int32)

    private func discriminant() -> Int32 {
        switch self {
        case .MANAGE_OFFER_SUCCESS:
            return ManageOfferResultCode.MANAGE_OFFER_SUCCESS
        case .failure (let code):
            return code
        }
    }
    
    init(from decoder: XDRDecoder) throws {
        let discriminant = try decoder.decode(Int32.self)
        
        switch discriminant {
        case ManageOfferResultCode.MANAGE_OFFER_SUCCESS:
            self = .MANAGE_OFFER_SUCCESS(try decoder.decode(ManageOfferSuccessResult.self))
        default:
            self = .failure(discriminant)
        }
    }
}
