import Foundation
import Security
import XCTest

enum TestKeys {
    static func make() throws -> Data {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2_048
        ]
        let key = try XCTUnwrap(SecKeyCreateRandomKey(attributes as CFDictionary, nil))
        return try XCTUnwrap(SecKeyCopyExternalRepresentation(key, nil) as Data?)
    }
}
