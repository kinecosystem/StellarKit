//
//  StellarErrors.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 06/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation

enum PaymentError: Int32, Error {
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
