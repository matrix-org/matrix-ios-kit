/*
 Copyright 2015 OpenMarket Ltd
 
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

#import <MatrixSDK/MatrixSDK.h>

typedef enum : NSUInteger {
    MXK3PIDAuthStateUnknown,
    MXK3PIDAuthStateTokenRequested,
    MXK3PIDAuthStateTokenReceived,
    MXK3PIDAuthStateTokenSubmitted,
    MXK3PIDAuthStateAuthenticated
} MXK3PIDAuthState;


@interface MXK3PID : NSObject

/**
 The 3rd party system where the user is defined.
 */
@property (nonatomic, readonly) MX3PIDMedium medium;

/**
 The id of the user in the 3rd party system.
 */
@property (nonatomic, readonly) NSString *address;

/**
 The current client secret key used during email validation.
 */
@property (nonatomic, readonly) NSString *clientSecret;

/**
 The current session identifier during email validation.
 */
@property (nonatomic, readonly) NSString *sid;

/**
 The id of the user on Matrix.
 nil if unknown or not yet resolved.
 */
@property (nonatomic) NSString *userId;

@property (nonatomic, readonly) MXK3PIDAuthState validationState;

/**
 Initialise the instance with a 3PID.

 @param medium the medium.
 @param address the id of the contact on this medium.
 @return the new instance.
 */
- (instancetype)initWithMedium:(NSString*)medium andAddress:(NSString*)address;

/**
 Start the validation process 
 The identity server will send a validation token to the user's address.
 
 In case of email, the end user must click on the link in the received email
 to validate their email address in order to be able to call add3PIDToUser successfully.
 
 @param restClient used to make matrix API requests during validation process.
 @param success A block object called when the operation succeeds.
 @param failure A block object called when the operation fails.
 */
- (void)requestValidationTokenWithMatrixRestClient:(MXRestClient*)restClient
                                           success:(void (^)())success
                                           failure:(void (^)(NSError *error))failure;
/**
 Link a 3rd party id to the user.
 
 @param bind whether the homeserver should also bind this third party identifier
        to the account's Matrix ID with the identity server.
 @param success A block object called when the operation succeeds. It provides the raw
 server response.
 @param failure A block object called when the operation fails.
 */
- (void)add3PIDToUser:(BOOL)bind
              success:(void (^)())success
              failure:(void (^)(NSError *error))failure;

@end