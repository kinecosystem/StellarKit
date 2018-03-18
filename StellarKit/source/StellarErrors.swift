//
//  StellarErrors.swift
//  StellarKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarErrors

public enum TransactionError: Int32, Error {
    case txFAILED = -1               // one of the operations failed (none were applied)

    case txTOO_EARLY = -2            // ledger closeTime before minTime
    case txTOO_LATE = -3             // ledger closeTime after maxTime
    case txMISSING_OPERATION = -4    // no operation was specified
    case txBAD_SEQ = -5              // sequence number does not match source account

    case txBAD_AUTH = -6             // too few valid signatures / wrong network
    case txINSUFFICIENT_BALANCE = -7 // fee would bring account below reserve
    case txNO_ACCOUNT = -8           // source account not found
    case txINSUFFICIENT_FEE = -9     // fee is too small
    case txBAD_AUTH_EXTRA = -10      // unused signatures attached to transaction
    case txINTERNAL_ERROR = -11      // an unknown error occured
}

public enum CreateAccountError: Int32, Error {
    case CREATE_ACCOUNT_MALFORMED = -1     // invalid destination
    case CREATE_ACCOUNT_UNDERFUNDED = -2   // not enough funds in source account
    case CREATE_ACCOUNT_LOW_RESERVE = -3   // would create an account below the min reserve
    case CREATE_ACCOUNT_ALREADY_EXIST = -4 // account already exists
}

public enum ChangeTrustError: Int32, Error {
    case CHANGE_TRUST_MALFORMED = -1         // bad input
    case CHANGE_TRUST_NO_ISSUER = -2         // could not find issuer
    case CHANGE_TRUST_INVALID_LIMIT = -3     // cannot drop limit below balance
    case CHANGE_TRUST_LOW_RESERVE = -4       // not enough funds to create a new trust line,
    case CHANGE_TRUST_SELF_NOT_ALLOWED = -5  // trusting self is not allowed
}

public enum PaymentError: Int32, Error {
    case PAYMENT_MALFORMED = -1          // bad input
    case PAYMENT_UNDERFUNDED = -2        // not enough funds in source account
    case PAYMENT_SRC_NO_TRUST = -3       // no trust line on source account
    case PAYMENT_SRC_NOT_AUTHORIZED = -4 // source not authorized to transfer
    case PAYMENT_NO_DESTINATION = -5     // destination account does not exist
    case PAYMENT_NO_TRUST = -6           // destination missing a trust line for asset
    case PAYMENT_NOT_AUTHORIZED = -7     // destination not authorized to hold asset
    case PAYMENT_LINE_FULL = -8          // destination would go above their limit
    case PAYMENT_NO_ISSUER = -9          // missing issuer on asset
}

func errorFromResponse(resultXDR: String) -> Error? {
    if let resultXDRData = Data(base64Encoded: resultXDR) {
        let result: TransactionResult
        do {
            result = try XDRDecoder.decode(TransactionResult.self, data: resultXDRData)
        }
        catch {
            return error
        }

        switch result.result {
        case .txSUCCESS:
            break
        case .txERROR (let code):
            if let transactionError = TransactionError(rawValue: code) {
                return transactionError
            }

            return StellarError.unknownError(resultXDR)
        case .txFAILED (let opResults):
            guard let opResult = opResults.first else {
                return StellarError.unknownError(resultXDR)
            }

            switch opResult {
            case .opINNER(let tr):
                switch tr {
                case .PAYMENT (let paymentResult):
                    switch paymentResult {
                    case .failure (let code):
                        if let paymentError = PaymentError(rawValue: code) {
                            return paymentError
                        }

                        return StellarError.unknownError(resultXDR)

                    default:
                        break
                    }
                case .CREATE_ACCOUNT (let createAccountResult):
                    switch createAccountResult {
                    case .failure (let code):
                        if let createAccountError = CreateAccountError(rawValue: code) {
                            return createAccountError
                        }

                        return StellarError.unknownError(resultXDR)

                    default:
                        break
                    }

                case .CHANGE_TRUST(let result):
                    switch result {
                    case .failure (let code):
                        if let error = ChangeTrustError(rawValue: code) {
                            return error
                        }

                    default:
                        break
                    }

                default:
                    break
                }

            default:
                break
            }
        }
    } else {
        return StellarError.unknownError(resultXDR)
    }

    return nil
}
