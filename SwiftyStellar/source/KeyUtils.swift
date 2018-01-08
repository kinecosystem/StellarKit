//
//  KeyUtils.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 08/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

/*
 Create:
 1. hash passphrase using hashed(string: String)
 2. generate salt using salt()

 Save:
 1. save file containing passphrase hash and salt

 Load:
 1. obtain passphrase
 2. obtain passphrase hash
 3. obtain salt
 4. generate key-pair using keyPair(from passphrase: String, hash: String, salt: String)
*/


enum KeyUtilsError: Error {
    case encodingFailed (String)
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

    static func keyPair(from passphrase: String, hash: String, salt: String) throws -> Sign.KeyPair? {
        let seed = try self.seed(from: passphrase, hash: hash, salt: salt)

        return keyPair(from: seed)
    }

    static func seed(from passphrase: String, hash: String, salt: String) throws -> Data {
        guard try verifyPassphrase(passphrase: passphrase, hash: hash) else {
            throw KeyUtilsError.passphraseIncorrect
        }

        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(passphrase)
        }

        guard let saltData = Data(hexString: salt) else {
            throw KeyUtilsError.encodingFailed(salt)
        }

        let sodium = Sodium()

        guard let seed = sodium.pwHash.hash(outputLength: 32,
                                            passwd: passphraseData,
                                            salt: saltData,
                                            opsLimit: sodium.pwHash.OpsLimitInteractive,
                                            memLimit: sodium.pwHash.MemLimitInteractive) else {
                                                throw KeyUtilsError.hashingFailed
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

    static func hashed(string: String) throws -> String {
        guard let stringData = string.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(string)
        }

        let sodium = Sodium()

        guard let hash = sodium.pwHash.str(passwd: stringData,
                                           opsLimit: sodium.pwHash.OpsLimitInteractive,
                                           memLimit: sodium.pwHash.MemLimitInteractive) else {
                                            throw KeyUtilsError.hashingFailed
        }

        return hash
    }

    static func verifyPassphrase(passphrase: String, hash: String) throws -> Bool {
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw KeyUtilsError.encodingFailed(passphrase)
        }

        let sodium = Sodium()

        return sodium.pwHash.strVerify(hash: hash, passwd: passphraseData)
    }

    static func salt() -> String? {
        return Sodium().randomBytes.buf(length: 16)?.hexString
    }
}
