/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

#import "MXKAccount.h"

#import "MXKAccountManager.h"
#import "MXKRoomDataSourceManager.h"
#import "MXKEventFormatter.h"

#import "MXKTools.h"

#import "MXKConstants.h"

#import "NSBundle+MatrixKit.h"

#import <AFNetworking/AFNetworking.h>

#import <MatrixSDK/MXBackgroundModeHandler.h>

NSString *const kMXKAccountUserInfoDidChangeNotification = @"kMXKAccountUserInfoDidChangeNotification";
NSString *const kMXKAccountAPNSActivityDidChangeNotification = @"kMXKAccountAPNSActivityDidChangeNotification";
NSString *const kMXKAccountPushKitActivityDidChangeNotification = @"kMXKAccountPushKitActivityDidChangeNotification";

NSString *const kMXKAccountErrorDomain = @"kMXKAccountErrorDomain";

static MXKAccountOnCertificateChange _onCertificateChangeBlock;

@interface MXKAccount ()
{
    // We will notify user only once on session failure
    BOOL notifyOpenSessionFailure;
    
    // The timer used to postpone server sync on failure
    NSTimer* initialServerSyncTimer;
    
    // Reachability observer
    id reachabilityObserver;
    
    // Session state observer
    id sessionStateObserver;
    
    // Handle user's settings change
    id userUpdateListener;
    
    // Used for logging application start up
    NSDate *openSessionStartDate;
    
    // Event notifications listener
    id notificationCenterListener;
    
    // Internal list of ignored rooms
    NSMutableArray* ignoredRooms;
    
    // If a server sync is in progress, the pause is delayed at the end of sync (except if resume is called).
    BOOL isPauseRequested;
    
    // Background sync management
    MXOnBackgroundSyncDone backgroundSyncDone;
    MXOnBackgroundSyncFail backgroundSyncfails;
    UIBackgroundTaskIdentifier backgroundSyncBgTask;
    NSTimer* backgroundSyncTimer;

    // Observe UIApplicationSignificantTimeChangeNotification to refresh MXRoomSummaries on time formatting change.
    id UIApplicationSignificantTimeChangeNotificationObserver;

    // Observe NSCurrentLocaleDidChangeNotification to refresh MXRoomSummaries on time formatting change.
    id NSCurrentLocaleDidChangeNotificationObserver;
}

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end

@implementation MXKAccount
@synthesize mxCredentials, mxSession, mxRestClient;
@synthesize threePIDs;
@synthesize userPresence;
@synthesize userTintColor;
@synthesize hideUserPresence;

+ (void)registerOnCertificateChangeBlock:(MXKAccountOnCertificateChange)onCertificateChangeBlock
{
    _onCertificateChangeBlock = onCertificateChangeBlock;
}

+ (UIColor*)presenceColor:(MXPresence)presence
{
    switch (presence)
    {
        case MXPresenceOnline:
            return [[MXKAppSettings standardAppSettings] presenceColorForOnlineUser];
        case MXPresenceUnavailable:
            return [[MXKAppSettings standardAppSettings] presenceColorForUnavailableUser];
        case MXPresenceOffline:
            return [[MXKAppSettings standardAppSettings] presenceColorForOfflineUser];
        case MXPresenceUnknown:
        default:
            return nil;
    }
}

- (instancetype)initWithCredentials:(MXCredentials*)credentials
{
    if (self = [super init])
    {
        notifyOpenSessionFailure = YES;
        
        // Report credentials and alloc REST client.
        mxCredentials = credentials;
        [self prepareRESTClient];
        
        userPresence = MXPresenceUnknown;
        
        // Refresh device information
        [self loadDeviceInformation:nil failure:nil];
    }
    return self;
}

- (void)dealloc
{
    [self closeSession:NO];
    mxSession = nil;
    
    [mxRestClient close];
    mxRestClient = nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self)
    {
        notifyOpenSessionFailure = YES;
        
        NSString *homeServerURL = [coder decodeObjectForKey:@"homeserverurl"];
        NSString *userId = [coder decodeObjectForKey:@"userid"];
        NSString *accessToken = [coder decodeObjectForKey:@"accesstoken"];
        
        mxCredentials = [[MXCredentials alloc] initWithHomeServer:homeServerURL
                                                           userId:userId
                                                      accessToken:accessToken];

        mxCredentials.deviceId = [coder decodeObjectForKey:@"deviceId"];  
        mxCredentials.allowedCertificate = [coder decodeObjectForKey:@"allowedCertificate"];
        
        [self prepareRESTClient];

        if ([coder decodeObjectForKey:@"threePIDs"])
        {
            threePIDs = [coder decodeObjectForKey:@"threePIDs"];
        }
        
        if ([coder decodeObjectForKey:@"device"])
        {
            _device = [coder decodeObjectForKey:@"device"];
        }

        userPresence = MXPresenceUnknown;
        
        if ([coder decodeObjectForKey:@"identityserverurl"])
        {
            _identityServerURL = [coder decodeObjectForKey:@"identityserverurl"];
            if (_identityServerURL.length)
            {
                // Update the current restClient
                [mxRestClient setIdentityServer:_identityServerURL];
            }
        }
        
        if ([coder decodeObjectForKey:@"pushgatewayurl"])
        {
            _pushGatewayURL = [coder decodeObjectForKey:@"pushgatewayurl"];
        }
        
        _enablePushNotifications = [coder decodeBoolForKey:@"_enablePushNotifications"];
        _enablePushKitNotifications = [coder decodeBoolForKey:@"enablePushKitNotifications"];
        _enableInAppNotifications = [coder decodeBoolForKey:@"enableInAppNotifications"];
        
        _disabled = [coder decodeBoolForKey:@"disabled"];

        _warnedAboutEncryption = [coder decodeBoolForKey:@"warnedAboutEncryption"];
        
        _showDecryptedContentInNotifications = [coder decodeBoolForKey:@"showDecryptedContentInNotifications"];
        
        // Refresh device information
        [self loadDeviceInformation:nil failure:nil];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:mxCredentials.homeServer forKey:@"homeserverurl"];
    [coder encodeObject:mxCredentials.userId forKey:@"userid"];
    [coder encodeObject:mxCredentials.accessToken forKey:@"accesstoken"];

    if (mxCredentials.deviceId)
    {
        [coder encodeObject:mxCredentials.deviceId forKey:@"deviceId"];
    }

    if (mxCredentials.allowedCertificate)
    {
        [coder encodeObject:mxCredentials.allowedCertificate forKey:@"allowedCertificate"];
    }

    if (self.threePIDs)
    {
        [coder encodeObject:threePIDs forKey:@"threePIDs"];
    }
    
    if (self.device)
    {
        [coder encodeObject:_device forKey:@"device"];
    }

    if (self.identityServerURL)
    {
        [coder encodeObject:_identityServerURL forKey:@"identityserverurl"];
    }
    
    if (self.pushGatewayURL)
    {
        [coder encodeObject:_pushGatewayURL forKey:@"pushgatewayurl"];
    }
    
    [coder encodeBool:_enablePushNotifications forKey:@"_enablePushNotifications"];
    [coder encodeBool:_enablePushKitNotifications forKey:@"enablePushKitNotifications"];
    [coder encodeBool:_enableInAppNotifications forKey:@"enableInAppNotifications"];
    
    [coder encodeBool:_disabled forKey:@"disabled"];

    [coder encodeBool:_warnedAboutEncryption forKey:@"warnedAboutEncryption"];
    
    [coder encodeBool:_showDecryptedContentInNotifications forKey:@"showDecryptedContentInNotifications"];
}

#pragma mark - Properties

- (void)setIdentityServerURL:(NSString *)identityServerURL
{
    if (identityServerURL.length)
    {
        _identityServerURL = identityServerURL;
        // Update the current restClient
        [mxRestClient setIdentityServer:identityServerURL];
    }
    else
    {
        _identityServerURL = nil;
        // By default, use the same address for the identity server
        [mxRestClient setIdentityServer:mxCredentials.homeServer];
    }
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (void)setPushGatewayURL:(NSString *)pushGatewayURL
{
    _pushGatewayURL = pushGatewayURL.length ? pushGatewayURL : nil;
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (NSString*)userDisplayName
{
    if (mxSession)
    {
        return mxSession.myUser.displayname;
    }
    return nil;
}

- (NSString*)userAvatarUrl
{
    if (mxSession)
    {
        return mxSession.myUser.avatarUrl;
    }
    return nil;
}

- (NSString*)fullDisplayName
{
    if (self.userDisplayName.length)
    {
        return [NSString stringWithFormat:@"%@ (%@)", self.userDisplayName, mxCredentials.userId];
    }
    else
    {
        return mxCredentials.userId;
    }
}

- (NSArray<MXThirdPartyIdentifier *> *)threePIDs
{
    return threePIDs;
}

- (NSArray<NSString *> *)linkedEmails
{
    NSMutableArray<NSString *> *linkedEmails = [NSMutableArray array];

    for (MXThirdPartyIdentifier *threePID in threePIDs)
    {
        if ([threePID.medium isEqualToString:kMX3PIDMediumEmail])
        {
            [linkedEmails addObject:threePID.address];
        }
    }

    return linkedEmails;
}

- (NSArray<NSString *> *)linkedPhoneNumbers
{
    NSMutableArray<NSString *> *linkedPhoneNumbers = [NSMutableArray array];
    
    for (MXThirdPartyIdentifier *threePID in threePIDs)
    {
        if ([threePID.medium isEqualToString:kMX3PIDMediumMSISDN])
        {
            [linkedPhoneNumbers addObject:threePID.address];
        }
    }
    
    return linkedPhoneNumbers;
}

- (UIColor*)userTintColor
{
    if (!userTintColor)
    {
        userTintColor = [MXKTools colorWithRGBValue:[mxCredentials.userId hash]];
    }
    
    return userTintColor;
}

- (BOOL)pushNotificationServiceIsActive
{
    return ([[MXKAccountManager sharedManager] isAPNSAvailable] && _enablePushNotifications && mxSession);
}

- (void)setEnablePushNotifications:(BOOL)enablePushNotifications
{
    if (enablePushNotifications)
    {
        _enablePushNotifications = YES;
        
        // Archive updated field
        [[MXKAccountManager sharedManager] saveAccounts];
        
        [self refreshAPNSPusher];
    }
    else if (_enablePushNotifications)
    {
        NSLog(@"[MXKAccount] Disable APNS for %@ account", self.mxCredentials.userId);
        
        // Delete the pusher, report the new value only on success.
        [self enableAPNSPusher:NO
                       success:^{
                           
                           _enablePushNotifications = NO;
                           
                           // Archive updated field
                           [[MXKAccountManager sharedManager] saveAccounts];
                           
                       }
                       failure:nil];
    }
}

- (BOOL)isPushKitNotificationActive
{
    return ([[MXKAccountManager sharedManager] isPushAvailable] && _enablePushKitNotifications && mxSession);
}

- (void)setEnablePushKitNotifications:(BOOL)enablePushKitNotifications
{
    if (enablePushKitNotifications)
    {
        _enablePushKitNotifications = YES;
        
        // Archive updated field
        [[MXKAccountManager sharedManager] saveAccounts];
        
        [self refreshPushKitPusher];
    }
    else if (_enablePushKitNotifications)
    {
        NSLog(@"[MXKAccount] Disable Push for %@ account", self.mxCredentials.userId);
        
        // Delete the pusher, report the new value only on success.
        [self enablePushKitPusher:NO
                   success:^{
                       
                       _enablePushKitNotifications = NO;
                       
                       // Archive updated field
                       [[MXKAccountManager sharedManager] saveAccounts];
                   }
                   failure:nil];
    }
}

- (void)setEnableInAppNotifications:(BOOL)enableInAppNotifications
{
    _enableInAppNotifications = enableInAppNotifications;
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (void)setDisabled:(BOOL)disabled
{
    if (_disabled != disabled)
    {
        _disabled = disabled;
        
        if (_disabled)
        {
            [self deletePusher];
            [self deletePushKitPusher];
            
            // Close session (keep the storage).
            [self closeSession:NO];
        }
        else if (!mxSession)
        {
            // Open a new matrix session
            id<MXStore> store = [[[MXKAccountManager sharedManager].storeClass alloc] init];
            
            [self openSessionWithStore:store];
        }
        
        // Archive updated field
        [[MXKAccountManager sharedManager] saveAccounts];
    }
}

- (void)setWarnedAboutEncryption:(BOOL)warnedAboutEncryption
{
    _warnedAboutEncryption = warnedAboutEncryption;

    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (void)setShowDecryptedContentInNotifications:(BOOL)showDecryptedContentInNotifications
{
    _showDecryptedContentInNotifications = showDecryptedContentInNotifications;
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

#pragma mark - Matrix user's profile

- (void)setUserDisplayName:(NSString*)displayname success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (mxSession && mxSession.myUser)
    {
        [mxSession.myUser setDisplayName:displayname
                                 success:^{
                                     if (success) {
                                         success();
                                     }
                                     
                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                                 }
                                 failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)setUserAvatarUrl:(NSString*)avatarUrl success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (mxSession && mxSession.myUser)
    {
        [mxSession.myUser setAvatarUrl:avatarUrl
                               success:^{
                                   if (success) {
                                       success();
                                   }
                                   
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                               }
                               failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)changePassword:(NSString*)oldPassword with:(NSString*)newPassword success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (mxSession)
    {
        [mxRestClient changePassword:oldPassword
                                with:newPassword
                             success:^{
                                 
                                 if (success) {
                                     success();
                                 }
                                 
                             }
                             failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)load3PIDs:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    [mxRestClient threePIDs:^(NSArray<MXThirdPartyIdentifier *> *threePIDs2) {

        threePIDs = threePIDs2;

        // Archive updated field
        [[MXKAccountManager sharedManager] saveAccounts];

        if (success)
        {
            success();
        }

    } failure:^(NSError *error) {
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)loadDeviceInformation:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (mxCredentials.deviceId)
    {
        [mxRestClient deviceByDeviceId:mxCredentials.deviceId success:^(MXDevice *device) {
            
            _device = device;
            
            // Archive updated field
            [[MXKAccountManager sharedManager] saveAccounts];
            
            if (success)
            {
                success();
            }
            
        } failure:^(NSError *error) {
            
            if (failure)
            {
                failure(error);
            }
            
        }];
    }
    else
    {
        _device = nil;
        if (success)
        {
            success();
        }
    }
}

- (void)setUserPresence:(MXPresence)presence andStatusMessage:(NSString *)statusMessage completion:(void (^)(void))completion
{
    userPresence = presence;
    
    if (mxSession && !hideUserPresence)
    {
        // Update user presence on server side
        [mxSession.myUser setPresence:userPresence
                     andStatusMessage:statusMessage
                              success:^{
                                  NSLog(@"[MXKAccount] %@: set user presence (%lu) succeeded", mxCredentials.userId, (unsigned long)userPresence);
                                  if (completion)
                                  {
                                      completion();
                                  }
                                  
                                  [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                              }
                              failure:^(NSError *error) {
                                  NSLog(@"[MXKAccount] %@: set user presence (%lu) failed", mxCredentials.userId, (unsigned long)userPresence);
                              }];
    }
    else if (hideUserPresence)
    {
        NSLog(@"[MXKAccount] %@: set user presence is disabled.", mxCredentials.userId);
    }
}

#pragma mark -

/**
 Create a matrix session based on the provided store.
 When store data is ready, the live stream is automatically launched by synchronising the session with the server.
 
 In case of failure during server sync, the method is reiterated until the data is up-to-date with the server.
 This loop is stopped if you call [MXCAccount closeSession:], it is suspended if you call [MXCAccount pauseInBackgroundTask].
 
 @param store the store to use for the session.
 */
-(void)openSessionWithStore:(id<MXStore>)store
{
    // Sanity check
    if (!mxCredentials || !mxRestClient)
    {
        NSLog(@"[MXKAccount] Matrix session cannot be created without credentials");
        return;
    }
    
    // Close potential session (keep associated store).
    [self closeSession:NO];
    
    openSessionStartDate = [NSDate date];
    
    // Instantiate new session
    mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];

    // Set default MXEvent -> NSString formatter
    MXKEventFormatter *eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:self.mxSession];
    eventFormatter.isForSubtitle = YES;

    // Apply the event types filter to display only the wanted event types.
    eventFormatter.eventTypesFilterForMessages = [MXKAppSettings standardAppSettings].eventsFilterForMessages;

    mxSession.roomSummaryUpdateDelegate = eventFormatter;

    // Observe UIApplicationSignificantTimeChangeNotification to refresh to MXRoomSummaries if date/time are shown.
    // UIApplicationSignificantTimeChangeNotification is posted if DST is updated, carrier time is updated
    UIApplicationSignificantTimeChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationSignificantTimeChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        [self onDateTimeFormatUpdate];
    }];


    // Observe NSCurrentLocaleDidChangeNotification to refresh MXRoomSummaries if date/time are shown.
    // NSCurrentLocaleDidChangeNotification is triggered when the time swicthes to AM/PM to 24h time format
    NSCurrentLocaleDidChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        [self onDateTimeFormatUpdate];
    }];
    
    // Force a date refresh for all the last messages.
    [self onDateTimeFormatUpdate];

    // Register session state observer
    sessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Check whether the concerned session is the associated one
        if (notif.object == mxSession)
        {
            [self onMatrixSessionStateChange];
        }
    }];
    
    __weak typeof(self) weakSelf = self;
    [mxSession setStore:store success:^{
        
        // Complete session registration by launching live stream
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        // Refresh pusher state
        [strongSelf refreshAPNSPusher];
        [strongSelf refreshPushKitPusher];
        
        // Launch server sync
        [strongSelf launchInitialServerSync];
        
    } failure:^(NSError *error) {
        
        // This cannot happen. Loading of MXFileStore cannot fail.
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->mxSession = nil;
        
        [[NSNotificationCenter defaultCenter] removeObserver:strongSelf->sessionStateObserver];
        strongSelf->sessionStateObserver = nil;
        
    }];
}

/**
 Close the matrix session.
 
 @param clearStore set YES to delete all store data.
 */
- (void)closeSession:(BOOL)clearStore
{
    NSLog(@"[MXKAccount] closeSession (%tu)", clearStore);
    
    if (NSCurrentLocaleDidChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:NSCurrentLocaleDidChangeNotificationObserver];
        NSCurrentLocaleDidChangeNotificationObserver = nil;
    }

    if (UIApplicationSignificantTimeChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationSignificantTimeChangeNotificationObserver];
        UIApplicationSignificantTimeChangeNotificationObserver = nil;
    }
    
    [self removeNotificationListener];
    
    if (reachabilityObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
    }
    
    if (sessionStateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:sessionStateObserver];
        sessionStateObserver = nil;
    }
    
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    if (userUpdateListener)
    {
        [mxSession.myUser removeListener:userUpdateListener];
        userUpdateListener = nil;
    }
    
    if (mxSession)
    {
        // Reset room data stored in memory
        [MXKRoomDataSourceManager removeSharedManagerForMatrixSession:mxSession];

        if (clearStore)
        {
            // Force a reload of device keys at the next session start.
            // This will fix potential UISIs other peoples receive for our messages.
            [mxSession.crypto resetDeviceKeys];
        }
        else
        {
            // For recomputing of room summaries as they are a cache of computed data
            [mxSession resetRoomsSummariesLastMessage];
        }

        // Close session
        [mxSession close];
        
        if (clearStore)
        {
            [mxSession.store deleteAllData];
        }
        
        mxSession = nil;
    }
    
    notifyOpenSessionFailure = YES;
}

- (void)logout:(void (^)(void))completion
{
    [self deletePusher];
    [self deletePushKitPusher];
    
    MXHTTPOperation *operation = [mxSession logout:^{
        
        [self closeSession:YES];
        if (completion)
        {
            completion();
        }
        
    } failure:^(NSError *error) {
        
        // Close the session even if the logout request failed
        [self closeSession:YES];
        if (completion)
        {
            completion();
        }
        
    }];
    
    // Do not retry on failure.
    operation.maxNumberOfTries = 1;
}

- (void)deletePusher
{
    if (self.pushNotificationServiceIsActive)
    {
        [self enableAPNSPusher:NO success:nil failure:nil];
    }
}

- (void)deletePushKitPusher
{
    if (self.isPushKitNotificationActive)
    {
        [self enablePushKitPusher:NO success:nil failure:nil];
    }
}

- (void)pauseInBackgroundTask
{
    // Reset internal flag
    isPauseRequested = NO;
    
    if (mxSession && mxSession.state == MXSessionStateRunning)
    {
        id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
        if (handler)
        {
            if (_bgTask == [handler invalidIdentifier])
            {
                _bgTask = [handler startBackgroundTaskWithName:@"MXKAccountBackgroundTask" completion:^{
                    
                    NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX expired", (unsigned long)_bgTask);
                    [handler endBackgrounTaskWithIdentifier:_bgTask];
                    _bgTask = [handler invalidIdentifier];
                    
                }];
            }
            
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX starts", (unsigned long)_bgTask);
        }
        
        // Pause SDK
        [mxSession pause];
        
        // Update user presence
        __weak typeof(self) weakSelf = self;
        [self setUserPresence:MXPresenceUnavailable andStatusMessage:nil completion:^{
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                
                if (self.bgTask != [handler invalidIdentifier])
                {
                    NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX ends", (unsigned long)self.bgTask);
                    [handler endBackgrounTaskWithIdentifier:self.bgTask];
                    self.bgTask = [handler invalidIdentifier];
                    NSLog(@"[MXKAccount] >>>>> background pause task finished");
                }
            }
            
        }];
    }
    else
    {
        // Cancel pending actions
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
        [initialServerSyncTimer invalidate];
        initialServerSyncTimer = nil;
        
        if (mxSession.state == MXSessionStateSyncInProgress || mxSession.state == MXSessionStateInitialised || mxSession.state == MXSessionStateStoreDataReady)
        {
            NSLog(@"[MXKAccount] Pause is delayed at the end of sync (current state %tu)", mxSession.state);
            isPauseRequested = YES;
        }
    }
}

- (void)resume
{
    isPauseRequested = NO;
    
    if (mxSession)
    {
        [self cancelBackgroundSync];
        
        if (mxSession.state == MXSessionStatePaused || mxSession.state == MXSessionStatePauseRequested)
        {
            // Resume SDK and update user presence
            [mxSession resume:^{
                [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
                
                [self refreshAPNSPusher];
                [self refreshPushKitPusher];
            }];
        }
        else if (mxSession.state == MXSessionStateStoreDataReady || mxSession.state == MXSessionStateInitialSyncFailed)
        {
            // The session initialisation was uncompleted, we try to complete it here.
            [self launchInitialServerSync];
            
            [self refreshAPNSPusher];
            [self refreshPushKitPusher];
        }
        else if (mxSession.state == MXSessionStateSyncInProgress)
        {
            [self refreshAPNSPusher];
            [self refreshPushKitPusher];
        }
        
        id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
        if (handler && _bgTask != [handler invalidIdentifier])
        {
            // Cancel background task
            [handler endBackgrounTaskWithIdentifier:_bgTask];
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX cancelled", (unsigned long)_bgTask);
            _bgTask = [handler invalidIdentifier];
        }
    }
}

- (void)reload:(BOOL)clearCache
{
    // close potential session
    [self closeSession:clearCache];
    
    if (!_disabled)
    {
        // Open a new matrix session
        id<MXStore> store = [[[MXKAccountManager sharedManager].storeClass alloc] init];
        [self openSessionWithStore:store];
    }
}

#pragma mark - Push notifications

// Refresh the APNS pusher state for this account on this device.
- (void)refreshAPNSPusher
{
    // Check the conditions required to run the pusher
    if (self.pushNotificationServiceIsActive)
    {
        NSLog(@"[MXKAccount] Refresh APNS pusher for %@ account", self.mxCredentials.userId);
        
        // Create/restore the pusher
        [self enableAPNSPusher:YES
                       success:nil
                       failure:^(NSError *error) {
                           
                           _enablePushNotifications = NO;
                           
                           // Archive updated field
                           [[MXKAccountManager sharedManager] saveAccounts];
                       }];
    }
    else if (_enablePushNotifications && mxSession)
    {
        // Turn off pusher if user denied remote notification.
        NSLog(@"[MXKAccount] Disable APNS pusher for %@ account (notifications are denied)", self.mxCredentials.userId);
        [self enableAPNSPusher:NO success:nil failure:nil];
    }
}

// Enable/Disable the APNS pusher for this account on this device on the Home Server.
- (void)enableAPNSPusher:(BOOL)enabled success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
#ifdef DEBUG
    NSString *appId = [[NSUserDefaults standardUserDefaults] objectForKey:@"pusherAppIdDev"];
#else
    NSString *appId = [[NSUserDefaults standardUserDefaults] objectForKey:@"pusherAppIdProd"];
#endif
    
    NSDictionary *pushData = @{@"url": self.pushGatewayURL};
    
    [self enablePusher:enabled appId:appId token:[MXKAccountManager sharedManager].apnsDeviceToken pushData:pushData success:^{
        
        NSLog(@"[MXKAccount] Succeeded to update APNS pusher for %@ (%d)", self.mxCredentials.userId, enabled);
        
        if (success)
        {
            success();
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
        
    } failure:^(NSError *error) {
        
        // Ignore error if the client try to disable an unknown token
        if (!enabled)
        {
            // Check whether the token was unknown
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringUnknown])
            {
                NSLog(@"[MXKAccount] APNS was already disabled for %@!", self.mxCredentials.userId);
                
                // Ignore the error
                if (success)
                {
                    success();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
                
                return;
            }
            
            NSLog(@"[MXKAccount] Failed to disable APNS %@! (%@)", self.mxCredentials.userId, error);
        }
        else
        {
            NSLog(@"[MXKAccount] Failed to send APNS token for %@! (%@)", self.mxCredentials.userId, error);
        }
        
        if (failure)
        {
            failure(error);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
    }];
}

// Refresh the PushKit pusher state for this account on this device.
- (void)refreshPushKitPusher
{
    // Check the conditions required to run the pusher
    if (self.isPushKitNotificationActive)
    {
        NSLog(@"[MXKAccount] Refresh PushKit pusher for %@ account", self.mxCredentials.userId);
        
        // Create/restore the pusher
        [self enablePushKitPusher:YES
                          success:nil
                          failure:^(NSError *error) {
                              
                              _enablePushKitNotifications = NO;
                              
                              // Archive updated field
                              [[MXKAccountManager sharedManager] saveAccounts];
                          }];
    }
    else if (_enablePushKitNotifications && mxSession)
    {
        // Turn off pusher if user denied remote notification.
        NSLog(@"[MXKAccount] Disable PushKit pusher for %@ account (notifications are denied)", self.mxCredentials.userId);
        [self enablePushKitPusher:NO success:nil failure:nil];
    }
}

// Enable/Disable the pusher based on PushKit for this account on this device on the Home Server.
- (void)enablePushKitPusher:(BOOL)enabled success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    NSString *appId = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushKitAppIdProd"];
    
    NSMutableDictionary *pushData = [NSMutableDictionary dictionaryWithDictionary:@{@"url": self.pushGatewayURL}];
    
    NSDictionary *options = [MXKAccountManager sharedManager].pushOptions;
    if (options.count)
    {
        [pushData addEntriesFromDictionary:options];
    }
    
    [self enablePusher:enabled appId:appId token:[MXKAccountManager sharedManager].pushDeviceToken pushData:pushData success:^{
        
        NSLog(@"[MXKAccount] Succeeded to update PushKit pusher for %@ (%d)", self.mxCredentials.userId, enabled);
        
        if (success)
        {
            success();
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountPushKitActivityDidChangeNotification object:mxCredentials.userId];
        
    } failure:^(NSError *error) {
        
        // Ignore error if the client try to disable an unknown token
        if (!enabled)
        {
            // Check whether the token was unknown
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringUnknown])
            {
                NSLog(@"[MXKAccount] Push was already disabled for %@!", self.mxCredentials.userId);
                
                // Ignore the error
                if (success)
                {
                    success();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountPushKitActivityDidChangeNotification object:mxCredentials.userId];
                
                return;
            }
            
            NSLog(@"[MXKAccount] Failed to disable Push %@! (%@)", self.mxCredentials.userId, error);
        }
        else
        {
            NSLog(@"[MXKAccount] Failed to send Push token for %@! (%@)", self.mxCredentials.userId, error);
        }
        
        if (failure)
        {
            failure(error);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountPushKitActivityDidChangeNotification object:mxCredentials.userId];
    }];
}

- (void)enablePusher:(BOOL)enabled appId:(NSString*)appId token:(NSData*)token pushData:(NSDictionary*)pushData success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    // Refuse to try & turn push on if we're not logged in, it's nonsensical.
    if (!mxCredentials)
    {
        NSLog(@"[MXKAccount] Not setting push token because we're not logged in");
        return;
    }
    
    // Check whether the Push Gateway URL has been configured.
    if (!self.pushGatewayURL)
    {
        NSLog(@"[MXKAccount] Not setting pusher because the Push Gateway URL is undefined");
        return;
    }
    
    if (!appId)
    {
        NSLog(@"[MXKAccount] Not setting pusher because pusher app id is undefined");
        return;
    }
    
    NSString *appDisplayName = [NSString stringWithFormat:@"%@ (iOS)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    
    NSString *b64Token = [token base64EncodedStringWithOptions:0];
    
    NSString *deviceLang = [NSLocale preferredLanguages][0];
    
    NSString * profileTag = [[NSUserDefaults standardUserDefaults] valueForKey:@"pusherProfileTag"];
    if (!profileTag)
    {
        profileTag = @"";
        NSString *alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        for (int i = 0; i < 16; ++i)
        {
            unsigned char c = [alphabet characterAtIndex:arc4random() % alphabet.length];
            profileTag = [profileTag stringByAppendingFormat:@"%c", c];
        }
        NSLog(@"[MXKAccount] Generated fresh profile tag: %@", profileTag);
        [[NSUserDefaults standardUserDefaults] setValue:profileTag forKey:@"pusherProfileTag"];
    }
    else
    {
        NSLog(@"[MXKAccount] Using existing profile tag: %@", profileTag);
    }
    
    NSObject *kind = enabled ? @"http" : [NSNull null];
    
    // Use the append flag to handle multiple accounts registration.
    BOOL append = NO;
    // Check whether a pusher is running for another account
    NSArray *activeAccounts = [MXKAccountManager sharedManager].activeAccounts;
    for (MXKAccount *account in activeAccounts)
    {
        if (![account.mxCredentials.userId isEqualToString:self.mxCredentials.userId] && account.pushNotificationServiceIsActive)
        {
            append = YES;
            break;
        }
    }
    NSLog(@"[MXKAccount] append flag: %d", append);
    
    MXRestClient *restCli = self.mxRestClient;
    
    [restCli setPusherWithPushkey:b64Token kind:kind appId:appId appDisplayName:appDisplayName deviceDisplayName:[[UIDevice currentDevice] name] profileTag:profileTag lang:deviceLang data:pushData append:append success:success failure:failure];
}

#pragma mark - InApp notifications

- (void)listenToNotifications:(MXOnNotification)onNotification
{
    // Check conditions required to add notification listener
    if (!mxSession || !onNotification)
    {
        return;
    }
    
    // Remove existing listener (if any)
    [self removeNotificationListener];
    
    // Register on notification center
    notificationCenterListener = [self.mxSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule)
    {
        // Apply first the event filter defined in the related room data source
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:event.roomId create:NO];
        
        if (roomDataSource)
        {
            if (!roomDataSource.eventFormatter.eventTypesFilterForMessages || [roomDataSource.eventFormatter.eventTypesFilterForMessages indexOfObject:event.type] != NSNotFound)
            {
                // Check conditions to report this notification
                if (nil == ignoredRooms || [ignoredRooms indexOfObject:event.roomId] == NSNotFound)
                {
                    onNotification(event, roomState, rule);
                }
            }
        }
    }];
}

- (void)removeNotificationListener
{
    if (notificationCenterListener)
    {
        [self.mxSession.notificationCenter removeListener:notificationCenterListener];
        notificationCenterListener = nil;
    }
    ignoredRooms = nil;
}

- (void)updateNotificationListenerForRoomId:(NSString*)roomID ignore:(BOOL)isIgnored
{
    if (isIgnored)
    {
        if (!ignoredRooms)
        {
            ignoredRooms = [[NSMutableArray alloc] init];
        }
        [ignoredRooms addObject:roomID];
    }
    else if (ignoredRooms)
    {
        [ignoredRooms removeObject:roomID];
    }
}

#pragma mark - Internals

- (void)launchInitialServerSync
{
    // Complete the session registration when store data is ready.
    
    // Cancel potential reachability observer and pending action
    [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
    reachabilityObserver = nil;
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    // Sanity check
    if (!mxSession || (mxSession.state != MXSessionStateStoreDataReady && mxSession.state != MXSessionStateInitialSyncFailed))
    {
        NSLog(@"[MXKAccount] Initial server sync is applicable only when store data is ready to complete session initialisation");
        return;
    }
    
    // Launch mxSession
    [mxSession start:^{
        
        NSLog(@"[MXKAccount] %@: The session is ready. Matrix SDK session has been started in %0.fms.", mxCredentials.userId, [[NSDate date] timeIntervalSinceDate:openSessionStartDate] * 1000);
        
        [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
        
    } failure:^(NSError *error) {
        
        NSLog(@"[MXKAccount] Initial Sync failed");
        if (notifyOpenSessionFailure && error)
        {
            // Notify MatrixKit user only once
            notifyOpenSessionFailure = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
        }
        
        // Check if it is a network connectivity issue
        AFNetworkReachabilityManager *networkReachabilityManager = [AFNetworkReachabilityManager sharedManager];
        NSLog(@"[MXKAccount] Network reachability: %d", networkReachabilityManager.isReachable);
        
        if (networkReachabilityManager.isReachable)
        {
            // The problem is not the network
            // Postpone a new attempt in 10 sec
            initialServerSyncTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(launchInitialServerSync) userInfo:self repeats:NO];
        }
        else
        {
            // The device is not connected to the internet, wait for the connection to be up again before retrying
            // Add observer to launch a new attempt according to reachability.
            reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                
                NSNumber *statusItem = note.userInfo[AFNetworkingReachabilityNotificationStatusItem];
                if (statusItem)
                {
                    AFNetworkReachabilityStatus reachabilityStatus = statusItem.integerValue;
                    if (reachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi || reachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN)
                    {
                        // New attempt
                        [self launchInitialServerSync];
                    }
                }
                
            }];
        }
    }];
}

- (void)onMatrixSessionStateChange
{
    if (mxSession.state == MXSessionStateRunning)
    {
        // Check if pause has been requested
        if (isPauseRequested)
        {
            NSLog(@"[MXKAccount] Apply the pending pause.");
            [self pauseInBackgroundTask];
            return;
        }
        
        // Check whether the session was not already running
        if (!userUpdateListener)
        {
            // Register listener to user's information change
            userUpdateListener = [mxSession.myUser listenToUserUpdate:^(MXEvent *event) {
                // Consider events related to user's presence
                if (event.eventType == MXEventTypePresence)
                {
                    userPresence = [MXTools presence:event.content[@"presence"]];
                }
                
                // Here displayname or other information have been updated, post update notification.
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
            }];
            
            // User information are just up-to-date (`mxSession` is running), post update notification.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
        }
    }
    else if (mxSession.state == MXSessionStateStoreDataReady || mxSession.state == MXSessionStateSyncInProgress)
    {
        // Remove listener (if any), this action is required to handle correctly matrix sdk handler reload (see clear cache)
        if (userUpdateListener)
        {
            [mxSession.myUser removeListener:userUpdateListener];
            userUpdateListener = nil;
        }
        else
        {
            // Here the initial server sync is in progress. The session is not running yet, but some user's information are available (from local storage).
            // We post update notification to let observer take into account this user's information even if they may not be up-to-date.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
        }
    }
    else if (mxSession.state == MXSessionStatePaused)
    {
        isPauseRequested = NO;
    }
    else if (mxSession.state == MXSessionStateUnknownToken)
    {
        // Logout this account
        [[MXKAccountManager sharedManager] removeAccount:self completion:nil];
    }
}

- (void)prepareRESTClient
{
    if (!mxCredentials)
    {
        return;
    }
    
    mxRestClient = [[MXRestClient alloc] initWithCredentials:mxCredentials andOnUnrecognizedCertificateBlock:^BOOL(NSData *certificate) {
        
        if (_onCertificateChangeBlock)
        {
            if (_onCertificateChangeBlock (self, certificate))
            {
                // Update the certificate in credentials
                mxCredentials.allowedCertificate = certificate;
                
                // Archive updated field
                [[MXKAccountManager sharedManager] saveAccounts];
                
                return YES;
            }
            
            mxCredentials.ignoredCertificate = certificate;
            
            // Archive updated field
            [[MXKAccountManager sharedManager] saveAccounts];
        }
        return NO;
    
    }];
}

- (void)onDateTimeFormatUpdate
{
    if ([mxSession.roomSummaryUpdateDelegate isKindOfClass:MXKEventFormatter.class])
    {
        MXKEventFormatter *eventFormatter = (MXKEventFormatter*)mxSession.roomSummaryUpdateDelegate;
        
        // Update the date and time formatters
        [eventFormatter initDateTimeFormatters];
        
        for (MXRoomSummary *summary in mxSession.roomsSummaries)
        {
            summary.lastMessageOthers[@"lastEventDate"] = [eventFormatter dateStringFromEvent:summary.lastMessageEvent withTime:YES];
            [mxSession.store storeSummaryForRoom:summary.roomId summary:summary];
        }
        
        // Commit store changes done
        if ([mxSession.store respondsToSelector:@selector(commit)])
        {
            [mxSession.store commit];
        }
        
        // Broadcast the change which concerns all the room summaries.
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXRoomSummaryDidChangeNotification object:nil userInfo:nil];
    }
}

#pragma mark - Crypto
- (void)resetDeviceId
{
    mxCredentials.deviceId = nil;

    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

#pragma mark - backgroundSync management

- (void)cancelBackgroundSync
{
    if (backgroundSyncBgTask != UIBackgroundTaskInvalid)
    {
        NSLog(@"[MXKAccount] The background Sync is cancelled.");

        if (mxSession)
        {
            if (mxSession.state == MXSessionStateBackgroundSyncInProgress)
            {
                [mxSession pause];
            }
        }
        
        [self onBackgroundSyncDone:[NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:nil]];
    }
}

- (void)onBackgroundSyncDone:(NSError*)error
{
    if (backgroundSyncTimer)
    {
        [backgroundSyncTimer invalidate];
        backgroundSyncTimer = nil;
    }
    
    if (backgroundSyncfails && error)
    {
        backgroundSyncfails(error);
    }
    
    if (backgroundSyncDone && !error)
    {
        backgroundSyncDone();
    }
    
    backgroundSyncDone = nil;
    backgroundSyncfails = nil;
    
    id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
    if (handler && backgroundSyncBgTask != [handler invalidIdentifier])
    {
        // End background task
        [handler endBackgrounTaskWithIdentifier:backgroundSyncBgTask];
        NSLog(@"[MXKAccount] onBackgroundSyncDone: %08lX stop", (unsigned long)backgroundSyncBgTask);
        backgroundSyncBgTask = [handler invalidIdentifier];
    }
}

- (void)onBackgroundSyncTimerOut
{
    [self cancelBackgroundSync];
}

- (void)backgroundSync:(unsigned int)timeout success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    // Check whether a background mode handler has been set.
    id<MXBackgroundModeHandler> handler = [MXSDKOptions sharedInstance].backgroundModeHandler;
    if (handler)
    {
        // Only work when the application is suspended.
        // Check conditions before launching background sync
        if (mxSession && mxSession.state == MXSessionStatePaused)
        {
            NSLog(@"[MXKAccount] starts a background Sync");
            
            backgroundSyncDone = success;
            backgroundSyncfails = failure;
            
            if (backgroundSyncBgTask != [handler invalidIdentifier])
            {
                [handler endBackgrounTaskWithIdentifier:backgroundSyncBgTask];
            }
            
            backgroundSyncBgTask = [handler startBackgroundTaskWithName:@"MXKAccountBackgroundSyncTask" completion:^{
                
                NSLog(@"[MXKAccount] the background Sync fails because of the bg task timeout");
                [self cancelBackgroundSync];
                
            }];
            
            // ensure that the backgroundSync will be really done in the expected time
            // the request could be done but the treatment could be long so add a timer to cancel it
            // if it takes too much time
            backgroundSyncTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:(timeout - 1) / 1000]
                                                           interval:0
                                                             target:self
                                                           selector:@selector(onBackgroundSyncTimerOut)
                                                           userInfo:nil
                                                            repeats:NO];
            
            [[NSRunLoop mainRunLoop] addTimer:backgroundSyncTimer forMode:NSDefaultRunLoopMode];
            
            [mxSession backgroundSync:timeout success:^{
                NSLog(@"[MXKAccount] the background Sync succeeds");
                [self onBackgroundSyncDone:nil];
                
            }
                              failure:^(NSError* error) {
                                  
                                  NSLog(@"[MXKAccount] the background Sync fails");
                                  [self onBackgroundSyncDone:error];
                                  
                              }
             
             ];
        }
        else
        {
            NSLog(@"[MXKAccount] cannot start background Sync (invalid state %tu)", mxSession.state);
            failure([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:nil]);
        }
    }
    else
    {
        NSLog(@"[MXKAccount] cannot start background Sync");
        failure([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:nil]);
    }
}


@end
