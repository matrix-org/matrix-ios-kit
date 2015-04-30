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
 Create a matrix session based on the provided store.
 When store data is ready, the live stream is automatically launched by synchronising the session with the server.
 
 In case of failure during server sync, the method is reiterated until the data is up-to-date with the server.
 This loop is stopped if you call [MXCAccount closeSession], it is suspended if you call [MXCAccount pauseInBackgroundTask].
 
 @param store the store to use for the session.
 */
-(void)openSessionWithStore:(id<MXStore>)store;

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

#pragma mark - Push notification listeners
/**
 Register a listener to push notifications for the account's session.
 
 The listener will be called when a push rule matches a live event.
 Note: only one listener is supported. Potential existing listener is removed.
 
 You may use `[MXCAccount updateNotificationListenerForRoomId:]` to disable/enable all notifications from a specific room.
 
 @param listenerBlock the block that will be called once a live event matches a push rule.
 */
- (void)listenToNotifications:(MXOnNotification)onNotification;

/**
 Unregister the listener.
 */
- (void)removeNotificationListener;

/**
 Update the listener to ignore or restore notifications from a specific room.
 
 @param roomID the id of the concerned room.
 @param isIgnored YES to disable notifications from the specified room. NO to restore them.
 */
- (void)updateNotificationListenerForRoomId:(NSString*)roomID ignore:(BOOL)isIgnored;

@end