//
//  Errors.swift
//  StellarErrors
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

public enum StellarError: Error {
    case memoTooLong(Any?)
    case missingAccount
    case missingBalance
    case missingSignClosure
    case urlEncodingFailed
    case dataEncodingFailed
    case dataDecodingFailed
    case signingFailed
}

extension StellarError: LocalizedError {
    public var errorDescription: String? {
        return String("\(self)")
    }
}
