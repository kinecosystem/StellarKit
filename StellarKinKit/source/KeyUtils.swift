//
//  KeyUtils.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

enum KeyUtilsError: Error {
    case encodingFailed (String)
    case decodingFailed (String)
    case hashingFailed
    case passphraseIncorrect
    case unknownError
}

struct KeyUtils {
    static func keyPair() -> Sign.KeyPair? {
        return Sodium().sign.keyPair()
    }

    static func keyPair(from seed: Data) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: seed)
    }

    static func keyPair(from seed: String) -> Sign.KeyPair? {
        return Sodium().sign.keyPair(seed: base32KeyToData(key: seed))
    }

    static func seed(from passphrase: String, encryptedSeed: String, salt: String) throws -> Data {
        guard let encryptedSeedData = Data(hexString: encryptedSeed) else {
            throw KeyUtilsError.decodingFailed(encryptedSeed)
        }

        let sodium = Sodium()

        let skey = try KeyUtils.keyHash(passphrase: passphrase, salt: salt)

        guard let seed = sodium.secretBox.open(nonceAndAuthenticatedCipherText: encryptedSeedData, secretKey: skey) else {
            throw KeyUtilsError.passphraseIncorrect
        }

        return seed
    }

    static func base32(publicKey: Data) -> String {
        return publicKeyToBase32(publicKey)
    }

    static func base32(seed: Data) -> String {
        return seedToBase32(seed)
    }

    static func key(base32: String) -> Data {
        return base32KeyToData(key: base32)
    }

    static func keyHash(passphrase: String, salt: String) throws -> Data {
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

    static func encryptSeed(_ seed: Data, secretKey: Data) -> Data? {
        return Sodium().secretBox.seal(message: seed, secretKey: secretKey)
    }

    static func seed() -> Data? {
        return Sodium().randomBytes.buf(length: 32)
    }

    static func salt() -> String? {
        return Sodium().randomBytes.buf(length: 16)?.hexString
    }
}
