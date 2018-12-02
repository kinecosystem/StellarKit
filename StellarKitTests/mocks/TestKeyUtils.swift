//
//  TestKeyUtils.swift
//  StellarKitTests
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarKit
import Sodium

enum KeyUtilsError: Error {
    case encodingFailed (String)
    case decodingFailed (String)
    case hashingFailed
    case passphraseIncorrect
    case unknownError
}

public struct TestKeyUtils {
    public static func keyPair(from seed: [UInt8]) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: seed)
    }

    public static func keyPair(from seed: String) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: KeyUtils.key(base32: seed))
    }

    public static func seed(from passphrase: String,
                            encryptedSeed: String,
                            salt: String) throws -> [UInt8] {
        guard let encryptedSeedData = Data(hexString: encryptedSeed) else {
            throw KeyUtilsError.decodingFailed(encryptedSeed)
        }

        let sodium = Sodium()

        let skey = try TestKeyUtils.keyHash(passphrase: passphrase, salt: salt)

        guard let seed = sodium
            .secretBox
            .open(nonceAndAuthenticatedCipherText: encryptedSeedData.array,
                  secretKey: skey) else {
                    throw KeyUtilsError.passphraseIncorrect
        }

        return seed
    }

    public static func keyHash(passphrase: String, salt: String) throws -> [UInt8] {
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(passphrase)
        }

        guard let saltData = Data(hexString: salt) else {
            throw KeyUtilsError.decodingFailed(salt)
        }

        let sodium = Sodium()

        guard let hash = sodium.pwHash.hash(outputLength: 32,
                                            passwd: passphraseData.array,
                                            salt: saltData.array,
                                            opsLimit: sodium.pwHash.OpsLimitInteractive,
                                            memLimit: sodium.pwHash.MemLimitInteractive) else {
                                                throw KeyUtilsError.hashingFailed
        }

        return hash
    }

    public static func encryptSeed(_ seed: Data, secretKey: [UInt8]) -> [UInt8]? {
        return Sodium().secretBox.seal(message: seed.array, secretKey: secretKey)
    }

    public static func seed() -> [UInt8]? {
        return Sodium().randomBytes.buf(length: 32)
    }

    public static func salt() -> String? {
        return Sodium().randomBytes.buf(length: 16)?.hexString
    }

    public static func sign(message: Data, signingKey: [UInt8]) throws -> [UInt8] {
        guard let signature = Sodium().sign.signature(message: message.array,
                                                      secretKey: signingKey) else {
            throw StellarError.signingFailed
        }

        return signature
    }
}
