//
//  KeyUtils.swift
//  StellarKitTests
//
//  Created by Avi Shevin on 05/03/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarKit

enum KeyUtilsError: Error {
    case encodingFailed (String)
    case decodingFailed (String)
    case hashingFailed
    case passphraseIncorrect
    case unknownError
}

public struct TestKeyUtils {
    public static func keyPair(from seed: Data) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: seed)
    }

    public static func keyPair(from seed: String) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: KeyUtils.key(base32: seed))
    }

    public static func seed(from passphrase: String,
                            encryptedSeed: String,
                            salt: String) throws -> Data {
        guard let encryptedSeedData = Data(hexString: encryptedSeed) else {
            throw KeyUtilsError.decodingFailed(encryptedSeed)
        }

        let sodium = Sodium()

        let skey = try TestKeyUtils.keyHash(passphrase: passphrase, salt: salt)

        guard let seed = sodium.secretBox.open(nonceAndAuthenticatedCipherText: encryptedSeedData,
                                               secretKey: skey) else {
                                                throw KeyUtilsError.passphraseIncorrect
        }

        return seed
    }

    public static func keyHash(passphrase: String, salt: String) throws -> Data {
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(passphrase)
        }

        guard let saltData = Data(hexString: salt) else {
            throw KeyUtilsError.decodingFailed(salt)
        }

        let sodium = Sodium()

        guard let hash = sodium.pwHash.hash(outputLength: 32,
                                            passwd: passphraseData,
                                            salt: saltData,
                                            opsLimit: sodium.pwHash.OpsLimitInteractive,
                                            memLimit: sodium.pwHash.MemLimitInteractive) else {
                                                throw KeyUtilsError.hashingFailed
        }

        return hash
    }

    public static func encryptSeed(_ seed: Data, secretKey: Data) -> Data? {
        return Sodium().secretBox.seal(message: seed, secretKey: secretKey)
    }

    public static func seed() -> Data? {
        return Sodium().randomBytes.buf(length: 32)
    }

    public static func salt() -> String? {
        return Sodium().randomBytes.buf(length: 16)?.hexString
    }

    public static func sign(message: Data, signingKey: Data) throws -> Data {
        guard let signature = Sodium().sign.signature(message: message, secretKey: signingKey) else {
            throw StellarError.signingFailed
        }

        return signature
    }
}
