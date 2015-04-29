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

/**
 `MXKAccount` object contains the credentials of a logged matrix user. It is used to handle matrix
 session and presence for this user.
 */
@interface MXKAccount : NSObject <NSCoding>

/**
 The account's credentials: homeserver, access token, user id.
 */
@property (nonatomic, readonly) MXCredentials *mxCredentials;

/**
 The identity server URL.
 */
@property (nonatomic) NSString *identityServerURL;

/**
 The matrix REST client used to make matrix API requests.
 */
@property (nonatomic, readonly) MXRestClient *mxRestClient;

/**
 The matrix session (nil by default).
 */
@property (nonatomic, readonly) MXSession *mxSession;

/**
 The matrix user's presence.
 */
@property (nonatomic, readonly) MXPresence userPresence;

/**
 Init `MXKAccount` instance with credentials.
 
 @param credentials user's credentials
 */
- (instancetype)initWithCredentials:(MXCredentials*)credentials;

/**
 Create a matrix session with the account's credentials based on the provided store.
 
 @param store the store to use for the session.
 @param onStoreDataReady A block object called when data have been loaded from the `store`.
 Note the data may not be up-to-date. You need to call [MXKAccount startSession:] to ensure the sync with
 the home server.
 @param failure A block object called when the operation fails.
 */
-(void)createSessionWithStore:(id<MXStore>)store success:(void (^)())onStoreDataReady failure:(void (^)(NSError *))failure;

/**
 Complete the session registration when store data is ready, by launching live stream.
 
 @param onServerSyncDone A block object called when the data is up-to-date with the server.
 @param failure A block object called when the operation fails.
 */
- (void)startSession:(void (^)())onServerSyncDone failure:(void (^)(NSError *))failure;

/**
 Close the matrix session.
 */
-(void)closeSession;

/**
 Pause the current matrix session.
 */
- (void)pauseInBackgroundTask;

/**
 Resume the current matrix session.
 */
- (void)resume;

@end