//
//  CommonCrypto.h
//  StellarKit
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

#ifndef CommonCrypto_h
#define CommonCrypto_h

#import <stdint.h>
#import <Availability.h>

typedef uint32_t CC_LONG;       /* 32 bit unsigned integer */
#define CC_SHA256_DIGEST_LENGTH     32          /* digest length in bytes */
extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md) __OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);

#endif /* CommonCrypto_h */
