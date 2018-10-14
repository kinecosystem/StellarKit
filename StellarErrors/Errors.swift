//
//  Errors.swift
//  StellarErrors
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public enum StellarError: Error {
    case memoTooLong (Any?)
    case missingAccount
    case missingPublicKey
    case missingHash
    case missingSequence
    case missingBalance
    case missingSignClosure
    case urlEncodingFailed
    case dataEncodingFailed
    case signingFailed
    case destinationNotReadyForAsset (Error, String?)
    case unknownError (Any?)
    case internalInconsistency
}

extension StellarError: LocalizedError {
    var errorDescription: String? {
        let description: String = {
            switch self {
            case .memoTooLong: return "Memo too long"
            case .missingAccount: return "Missing account"
            case .missingPublicKey: return "Missing public key"
            case .missingHash: return "Missing hash"
            case .missingSequence: return "Missing sequence"
            case .missingBalance: return "Missing balance"
            case .missingSignClosure: return "Missing sign closure"
            case .urlEncodingFailed: return "URL encoding failed"
            case .dataEncodingFailed: return "Data encoding failed"
            case .signingFailed: return "Signing failed"
            case .destinationNotReadyForAsset: return "Destination not ready for asset"
            case .unknownError: return "Unknown Error"
            case .internalInconsistency: return "Internal inconsistency"
            }
        }()

        return "Stellar error: \(description)"
    }
}
