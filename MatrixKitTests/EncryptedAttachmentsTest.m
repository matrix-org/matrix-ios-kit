/*
 Copyright 2016 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "MXEncryptedAttachments.h"

@interface EncryptedAttachmentsTest : XCTestCase

@end


@implementation EncryptedAttachmentsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testDecrypt {
    NSArray *testVectors =
        @[
             @[@"", @{
                 @"v": @"v1",
                 @"hashes": @{
                     @"sha256": @"47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU"
                 },
                 @"key": @{
                     @"alg": @"A256CTR",
                     @"k": @"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                     @"key_ops": @[@"encrypt", @"decrypt"],
                     @"kty": @"oct"
                 },
                 @"iv": @"AAAAAAAAAAAAAAAAAAAAAA"
             }, @""],
             @[@"nZxRAVw962fwUQ5/", @{
                 @"v": @"v1",
                 @"hashes": @{
                     @"sha256": @"geLWS2ptBew5aPLJRTK+QnI3Krdl3UaxN8qfahHWhfc"
                 }, @"key": @{
                     @"alg": @"A256CTR",
                     @"k": @"__________________________________________8",
                     @"key_ops": @[@"encrypt", @"decrypt"],
                     @"kty": @"oct"
                 }, @"iv": @"/////////////////////w"
             }, @"SGVsbG8sIFdvcmxk"],
             @[@"tJVNBVJ/vl36UQt4Y5e5m84bRUrQHhcdLPvS/7EkDvlkDLZXamBB6k8THbiawiKZ5Mnq9PZMSSbgOCvmnUBOMA", @{
                @"v": @"v1",
                @"hashes": @{
                        @"sha256": @"LYG/orOViuFwovJpv2YMLSsmVKwLt7pY3f8SYM7KU5E"
                        },
                @"key": @{
                        @"kty": @"oct",
                        @"key_ops": @[@"encrypt",@"decrypt"],
                        @"k": @"__________________________________________8",
                        @"alg": @"A256CTR"
                        },
                @"iv": @"/////////////////////w"
                }, @"YWxwaGFudW1lcmljYWxseWFscGhhbnVtZXJpY2FsbHlhbHBoYW51bWVyaWNhbGx5YWxwaGFudW1lcmljYWxseQ"]
     ];
    
    for (NSArray *vector in testVectors) {
        NSString *inputCiphertext = vector[0];
        NSDictionary *inputInfo = vector[1];
        NSString *want = vector[2];
        
        NSData *ctData = [[NSData alloc] initWithBase64EncodedString:[MXEncryptedAttachments padBase64:inputCiphertext] options:0];
        NSInputStream *inputStream = [NSInputStream inputStreamWithData:ctData];
        NSOutputStream *outputStream = [NSOutputStream outputStreamToMemory];
        
        NSError *err = [MXEncryptedAttachments decryptAttachment:inputInfo inputStream:inputStream outputStream:outputStream];
        XCTAssertNil(err);
        NSData *gotData = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        
        NSData *wantData = [[NSData alloc] initWithBase64EncodedString:[MXEncryptedAttachments padBase64:want] options:0];
        
        XCTAssertEqualObjects(wantData, gotData, "Decrypted data did not match expectation.");
    }
}

@end
