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

#import "MXKContactManager.h"

#import "MXKContact.h"

#import "MXKAppSettings.h"
#import "MXKTools.h"
#import "NSBundle+MatrixKit.h"

NSString *const kMXKContactManagerDidUpdateMatrixContactsNotification = @"kMXKContactManagerDidUpdateMatrixContactsNotification";

NSString *const kMXKContactManagerDidUpdateLocalContactsNotification = @"kMXKContactManagerDidUpdateLocalContactsNotification";
NSString *const kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification = @"kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification";

NSString *const kMXKContactManagerMatrixUserPresenceChangeNotification = @"kMXKContactManagerMatrixUserPresenceChangeNotification";
NSString *const kMXKContactManagerMatrixPresenceKey = @"kMXKContactManagerMatrixPresenceKey";

NSString *const kMXKContactManagerDidInternationalizeNotification = @"kMXKContactManagerDidInternationalizeNotification";

@interface MXKContactManager()
{
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    id mxSessionStateObserver;
    id mxSessionNewSyncedRoomObserver;
    
    /**
     Listeners registered on matrix presence and membership events (one by matrix session)
     */
    NSMutableArray *mxEventListeners;
    
    /**
     Local contacts handling
     */
    BOOL isLocalContactListRefreshing;
    dispatch_queue_t processingQueue;
    NSDate *lastSyncDate;
    // Local contacts by contact Id
    NSMutableDictionary* localContactByContactID;
    NSMutableArray* localContactsWithMethods;
    NSMutableArray* splitLocalContacts;
    
    // Matrix id linked to 3PID.
    NSMutableDictionary<NSString*, NSString*> *matrixIDBy3PID;
    
    /**
     Matrix contacts handling
     */
    // Matrix contacts by contact Id
    NSMutableDictionary* matrixContactByContactID;
    // Matrix contacts by matrix id
    NSMutableDictionary* matrixContactByMatrixID;
}

/**
 The current REST client defined with the identity server.
 */
@property (nonatomic) MXRestClient *identityRESTClient;
@end

@implementation MXKContactManager
@synthesize contactManagerMXRoomSource;

#pragma mark Singleton Methods

+ (instancetype)sharedManager
{
    static MXKContactManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MXKContactManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark -

-(MXKContactManager *)init
{
    if (self = [super init])
    {
        NSString *label = [NSString stringWithFormat:@"MatrixKit.%@.Contacts", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
        
        processingQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // save the last sync date
        // to avoid resync the whole phonebook
        lastSyncDate = nil;
        
        self.contactManagerMXRoomSource = MXKContactManagerMXRoomSourceDirectChats;
        
        // Observe related settings change
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"syncLocalContacts" options:0 context:nil];
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"phonebookCountryCode" options:0 context:nil];
    }
    
    return self;
}

-(void)dealloc
{
    matrixIDBy3PID = nil;

    localContactByContactID = nil;
    localContactsWithMethods = nil;
    splitLocalContacts = nil;
    
    matrixContactByContactID = nil;
    matrixContactByMatrixID = nil;
    
    lastSyncDate = nil;
    
    while (mxSessionArray.count) {
        [self removeMatrixSession:mxSessionArray.lastObject];
    }
    mxSessionArray = nil;
    mxEventListeners = nil;
    _identityServer = nil;
    _identityRESTClient = nil;
    
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"syncLocalContacts"];
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"phonebookCountryCode"];
    
    processingQueue = nil;
}

#pragma mark -

- (void)addMatrixSession:(MXSession*)mxSession
{
    if (!mxSession)
    {
        return;
    }
    
    if (!mxSessionArray)
    {
        mxSessionArray = [NSMutableArray array];
    }
    if (!mxEventListeners)
    {
        mxEventListeners = [NSMutableArray array];
    }
    
    if ([mxSessionArray indexOfObject:mxSession] == NSNotFound)
    {
        [mxSessionArray addObject:mxSession];
        
        MXWeakify(self);
        
        // Register a listener on matrix presence and membership events
        id eventListener = [mxSession listenToEventsOfTypes:@[kMXEventTypeStringRoomMember, kMXEventTypeStringPresence]
                                                       onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
                                                           
                               MXStrongifyAndReturnIfNil(self);
                                                           
                               // Consider only live event
                               if (direction == MXTimelineDirectionForwards)
                               {
                                   // Consider first presence events
                                   if (event.eventType == MXEventTypePresence)
                                   {
                                       // Check whether the concerned matrix user belongs to at least one contact.
                                       BOOL isMatched = ([self->matrixContactByMatrixID objectForKey:event.sender] != nil);
                                       if (!isMatched)
                                       {
                                           NSArray *matrixIDs = [self->matrixIDBy3PID allValues];
                                           isMatched = ([matrixIDs indexOfObject:event.sender] != NSNotFound);
                                       }
                                       
                                       if (isMatched) {
                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerMatrixUserPresenceChangeNotification object:event.sender userInfo:@{kMXKContactManagerMatrixPresenceKey:event.content[@"presence"]}];
                                       }
                                   }
                                   // Else the event type is MXEventTypeRoomMember.
                                   // Ignore here membership events if the session is not running yet,
                                   // Indeed all the contacts are refreshed when session state becomes running.
                                   else if (mxSession.state == MXSessionStateRunning)
                                   {
                                       // Update matrix contact list on membership change
                                       [self updateMatrixContactWithID:event.sender];
                                   }
                               }
                           }];
        
        [mxEventListeners addObject:eventListener];
        
        // Update matrix contact list in case of new synced one-to-one room
        if (!mxSessionNewSyncedRoomObserver)
        {
            mxSessionNewSyncedRoomObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                MXStrongifyAndReturnIfNil(self);
                
                // create contact for known room members
                if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
                {
                    MXRoom *room = notif.object;
                    [room state:^(MXRoomState *roomState) {

                        MXRoomMembers *roomMembers = roomState.members;

                        NSArray *members = roomMembers.members;

                        // Consider only 1:1 chat for MXKMemberContactCreationOneToOneRoom
                        // or adding all
                        if (((members.count == 2) && (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats)) || (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll))
                        {
                            NSString* myUserId = room.mxSession.myUser.userId;

                            for (MXRoomMember* member in members)
                            {
                                if ([member.userId isEqualToString:myUserId])
                                {
                                    [self updateMatrixContactWithID:member.userId];
                                }
                            }
                        }
                    }];
                }
            }];
        }
        
        // Update all matrix contacts as soon as matrix session is ready
        if (!mxSessionStateObserver) {
            mxSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                MXStrongifyAndReturnIfNil(self);
                
                MXSession *mxSession = notif.object;
                
                if ([self->mxSessionArray indexOfObject:mxSession] != NSNotFound)
                {
                    if ((mxSession.state == MXSessionStateStoreDataReady) || (mxSession.state == MXSessionStateRunning)) {
                        [self refreshMatrixContacts];
                    }
                }
            }];
        }

        // refreshMatrixContacts can take time. Delay its execution to not overload
        // launch of apps that call [MXKContactManager addMatrixSession] at startup
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshMatrixContacts];
        });
    }
    
    // Lookup the matrix users in all the local contacts.
    [self updateMatrixIDsForAllLocalContacts];
}

- (void)removeMatrixSession:(MXSession*)mxSession
{
    if (!mxSession)
    {
        return;
    }
    
    NSUInteger index = [mxSessionArray indexOfObject:mxSession];
    if (index != NSNotFound)
    {
        id eventListener = [mxEventListeners objectAtIndex:index];
        [mxSession removeListener:eventListener];
        
        [mxEventListeners removeObjectAtIndex:index];
        [mxSessionArray removeObjectAtIndex:index];
        
        // Reset the current rest client (It will be rebuild if need)
        _identityRESTClient = nil;
        
        if (!mxSessionArray.count) {
            if (mxSessionStateObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionStateObserver];
                mxSessionStateObserver = nil;
            }
            
            if (mxSessionNewSyncedRoomObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionNewSyncedRoomObserver];
                mxSessionNewSyncedRoomObserver = nil;
            }
        }
        
        // Update matrix contacts list
        [self refreshMatrixContacts];
    }
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}


- (NSArray*)matrixContacts
{
    NSParameterAssert([NSThread isMainThread]);

    return [matrixContactByContactID allValues];
}

- (NSArray*)localContacts
{
    NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    return [localContactByContactID allValues];
}

- (NSArray*)localContactsWithMethods
{
    NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    // Check whether the array must be prepared
    if (!localContactsWithMethods)
    {
        // List all the local contacts with emails and/or phones
        NSArray *localContacts = self.localContacts;
        localContactsWithMethods = [NSMutableArray arrayWithCapacity:localContacts.count];
        
        for (MXKContact* contact in localContacts)
        {
            if (contact.emailAddresses)
            {
                [localContactsWithMethods addObject:contact];
            }
            else if (contact.phoneNumbers)
            {
                [localContactsWithMethods addObject:contact];
            }
        }
    }
    
    return localContactsWithMethods;
}

- (NSArray*)localContactsSplitByContactMethod
{
   NSParameterAssert([NSThread isMainThread]);

    // Return nil if the loading step is in progress.
    if (isLocalContactListRefreshing)
    {
        return nil;
    }
    
    // Check whether the array must be prepared
    if (!splitLocalContacts)
    {
        // List all the local contacts with contact methods
        NSArray *contactsArray = self.localContactsWithMethods;
        
        splitLocalContacts = [NSMutableArray arrayWithCapacity:contactsArray.count];
        
        for (MXKContact* contact in contactsArray)
        {
            NSArray *emails = contact.emailAddresses;
            NSArray *phones = contact.phoneNumbers;
            
            if (emails.count + phones.count > 1)
            {
                for (MXKEmail *email in emails)
                {
                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:@[email] phoneNumbers:nil andThumbnail:contact.thumbnail];
                    [splitLocalContacts addObject:splitContact];
                }
                
                for (MXKPhoneNumber *phone in phones)
                {
                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:nil phoneNumbers:@[phone] andThumbnail:contact.thumbnail];
                    [splitLocalContacts addObject:splitContact];
                }
            }
            else if (emails.count + phones.count)
            {
                [splitLocalContacts addObject:contact];
            }
        }
        
        // Sort alphabetically the resulting list
        [self sortAlphabeticallyContacts:splitLocalContacts];
    }
    
    return splitLocalContacts;
}


//- (void)localContactsSplitByContactMethod:(void (^)(NSArray<MXKContact*> *localContactsSplitByContactMethod))onComplete
//{
//    NSParameterAssert([NSThread isMainThread]);
//
//    // Return nil if the loading step is in progress.
//    if (isLocalContactListRefreshing)
//    {
//        onComplete(nil);
//        return;
//    }
//    
//    // Check whether the array must be prepared
//    if (!splitLocalContacts)
//    {
//        // List all the local contacts with contact methods
//        NSArray *contactsArray = self.localContactsWithMethods;
//        
//        splitLocalContacts = [NSMutableArray arrayWithCapacity:contactsArray.count];
//        
//        for (MXKContact* contact in contactsArray)
//        {
//            NSArray *emails = contact.emailAddresses;
//            NSArray *phones = contact.phoneNumbers;
//            
//            if (emails.count + phones.count > 1)
//            {
//                for (MXKEmail *email in emails)
//                {
//                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:@[email] phoneNumbers:nil andThumbnail:contact.thumbnail];
//                    [splitLocalContacts addObject:splitContact];
//                }
//                
//                for (MXKPhoneNumber *phone in phones)
//                {
//                    MXKContact *splitContact = [[MXKContact alloc] initContactWithDisplayName:contact.displayName emails:nil phoneNumbers:@[phone] andThumbnail:contact.thumbnail];
//                    [splitLocalContacts addObject:splitContact];
//                }
//            }
//            else if (emails.count + phones.count)
//            {
//                [splitLocalContacts addObject:contact];
//            }
//        }
//        
//        // Sort alphabetically the resulting list
//        [self sortAlphabeticallyContacts:splitLocalContacts];
//    }
//    
//    onComplete(splitLocalContacts);
//}

- (NSArray*)directMatrixContacts
{
    NSParameterAssert([NSThread isMainThread]);

    NSMutableDictionary *directContacts = [NSMutableDictionary dictionary];
    
    NSArray *mxSessions = self.mxSessions;
    
    for (MXSession *mxSession in mxSessions)
    {
        // Check all existing users for whom a direct chat exists
        NSArray *mxUserIds = mxSession.directRooms.allKeys;
        
        for (NSString *mxUserId in mxUserIds)
        {
            MXKContact* contact = [matrixContactByMatrixID objectForKey:mxUserId];
            
            // Sanity check - the contact must be already defined here
            if (contact)
            {
                [directContacts setValue:contact forKey:mxUserId];
            }
        }
    }
    
    return directContacts.allValues;
}

- (void)setIdentityServer:(NSString *)identityServer
{
    _identityServer = identityServer;
    
    if (identityServer)
    {
        MXCredentials *credentials = [MXCredentials new];
        credentials.identityServer = identityServer;

        _identityRESTClient = [[MXRestClient alloc] initWithCredentials:credentials andOnUnrecognizedCertificateBlock:nil];
        
        // Lookup the matrix users in all the local contacts.
        [self updateMatrixIDsForAllLocalContacts];
    }
    else
    {
        _identityRESTClient = nil;
    }
}

- (MXRestClient*)identityRESTClient
{
    if (!_identityRESTClient)
    {
        if (self.identityServer)
        {
            MXCredentials *credentials = [MXCredentials new];
            credentials.identityServer = self.identityServer;

            _identityRESTClient = [[MXRestClient alloc] initWithCredentials:credentials andOnUnrecognizedCertificateBlock:nil];
        }
        else if (mxSessionArray.count)
        {
            MXSession *mxSession = [mxSessionArray firstObject];

            MXCredentials *credentials = [MXCredentials new];
            credentials.identityServer = mxSession.matrixRestClient.identityServer;

            _identityRESTClient = [[MXRestClient alloc] initWithCredentials:credentials andOnUnrecognizedCertificateBlock:nil];
        }
    }
    
    return _identityRESTClient;
}

#pragma mark -

- (void)refreshLocalContacts
{
    NSLog(@"[MXKContactManager] refreshLocalContacts : Started");
    
    NSDate *startDate = [NSDate date];
    
    MXWeakify(self);
    
    [MXKTools checkAccessForContacts:nil showPopUpInViewController:nil completionHandler:^(BOOL granted) {

        MXStrongifyAndReturnIfNil(self);
        
        if (!granted)
        {
            if ([MXKAppSettings standardAppSettings].syncLocalContacts)
            {
                // The user authorised syncLocalContacts and allowed access to his contacts
                // but he then removed contacts access from app permissions.
                // So, reset syncLocalContacts value
                [MXKAppSettings standardAppSettings].syncLocalContacts = NO;
            }
            
            // Local contacts list is empty if the access is denied.
            self->localContactByContactID = nil;
            self->localContactsWithMethods = nil;
            self->splitLocalContacts = nil;
            [self cacheLocalContacts];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
            
            NSLog(@"[MXKContactManager] refreshLocalContacts : Complete");
            NSLog(@"[MXKContactManager] refreshLocalContacts : Local contacts access denied");
        }
        else
        {
            self->isLocalContactListRefreshing = YES;
            
            // Reset the internal contact lists (These arrays will be prepared only if need).
            self->localContactsWithMethods = self->splitLocalContacts = nil;
            
            BOOL isColdStart = NO;
            
            // Check whether the local contacts sync has been disabled.
            if (self->matrixIDBy3PID && ![MXKAppSettings standardAppSettings].syncLocalContacts)
            {
                // The user changed his mind and disabled the local contact sync, remove the cached data.
                self->matrixIDBy3PID = nil;
                [self cacheMatrixIDsDict];
                
                // Reload the local contacts from the system
                self->localContactByContactID = nil;
                [self cacheLocalContacts];
            }
            
            // Check whether this is a cold start.
            if (!self->matrixIDBy3PID)
            {
                isColdStart = YES;
                
                // Load the dictionary from the file system. It is cached to improve UX.
                [self loadCachedMatrixIDsDict];
            }
            
            dispatch_async(self->processingQueue, ^{
                
                MXStrongifyAndReturnIfNil(self);

                // In case of cold start, retrieve the data from the file system
                if (isColdStart)
                {
                    [self loadCachedLocalContacts];
                    [self loadCachedContactBookInfo];

                    // no local contact -> assume that the last sync date is useless
                    if (self->localContactByContactID.count == 0)
                    {
                        self->lastSyncDate = nil;
                    }
                }

                BOOL didContactBookChange = NO;

                NSMutableArray* deletedContactIDs = [NSMutableArray arrayWithArray:[self->localContactByContactID allKeys]];

                // can list local contacts?
                if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
                {
                    NSString* countryCode = [[MXKAppSettings standardAppSettings] phonebookCountryCode];

                    ABAddressBookRef ab = ABAddressBookCreateWithOptions(nil, nil);
                    ABRecordRef      contactRecord;
                    CFIndex          index;
                    CFMutableArrayRef people = (CFMutableArrayRef)ABAddressBookCopyArrayOfAllPeople(ab);

                    if (nil != people)
                    {
                        CFIndex peopleCount = CFArrayGetCount(people);

                        for (index = 0; index < peopleCount; index++)
                        {
                            contactRecord = (ABRecordRef)CFArrayGetValueAtIndex(people, index);

                            NSString* contactID = [MXKContact contactID:contactRecord];

                            // the contact still exists
                            [deletedContactIDs removeObject:contactID];

                            if (self->lastSyncDate)
                            {
                                // ignore unchanged contacts since the previous sync
                                CFDateRef lastModifDate = ABRecordCopyValue(contactRecord, kABPersonModificationDateProperty);
                                if (lastModifDate)
                                {
                                    if (kCFCompareGreaterThan != CFDateCompare(lastModifDate, (__bridge CFDateRef)self->lastSyncDate, nil))

                                    {
                                        CFRelease(lastModifDate);
                                        continue;
                                    }
                                    CFRelease(lastModifDate);
                                }
                            }

                            didContactBookChange = YES;

                            MXKContact* contact = [[MXKContact alloc] initLocalContactWithABRecord:contactRecord];

                            if (countryCode)
                            {
                                contact.defaultCountryCode = countryCode;
                            }

                            // update the local contacts list
                            [self->localContactByContactID setValue:contact forKey:contactID];
                        }

                        CFRelease(people);
                    }

                    if (ab)
                    {
                        CFRelease(ab);
                    }
                }

                // some contacts have been deleted
                for (NSString* contactID in deletedContactIDs)
                {
                    didContactBookChange = YES;
                    [self->localContactByContactID removeObjectForKey:contactID];
                }

                // something has been modified in the local contact book
                if (didContactBookChange)
                {
                    [self cacheLocalContacts];
                }
                
                self->lastSyncDate = [NSDate date];
                [self cacheContactBookInfo];
                
                // Update loaded contacts with the known dict 3PID -> matrix ID
                [self updateAllLocalContactsMatrixIDs];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // Contacts are loaded, post a notification
                    self->isLocalContactListRefreshing = NO;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
                    
                    // Check the conditions required before triggering a matrix users lookup.
                    if (isColdStart || didContactBookChange)
                    {
                        [self updateMatrixIDsForAllLocalContacts];
                    }
                    
                    NSLog(@"[MXKContactManager] refreshLocalContacts : Complete");
                    NSLog(@"[MXKContactManager] refreshLocalContacts : Refresh %tu local contacts in %.0fms", self->localContactByContactID.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
                });
            });
        }
    }];
}

- (void)updateMatrixIDsForLocalContact:(MXKContact *)contact
{
    // Check if the user allowed to sync local contacts.
    // + Check if at least an identity server is available.
    if ([MXKAppSettings standardAppSettings].syncLocalContacts && !contact.isMatrixContact && self.identityRESTClient)
    {
        // Retrieve all 3PIDs of the contact
        NSMutableArray* threepids = [[NSMutableArray alloc] init];
        NSMutableArray* lookup3pidsArray = [[NSMutableArray alloc] init];
        
        for (MXKEmail* email in contact.emailAddresses)
        {
            // Not yet added
            if (email.emailAddress.length && [threepids indexOfObject:email.emailAddress] == NSNotFound)
            {
                [lookup3pidsArray addObject:@[kMX3PIDMediumEmail, email.emailAddress]];
                [threepids addObject:email.emailAddress];
            }
        }
        
        for (MXKPhoneNumber* phone in contact.phoneNumbers)
        {
            if (phone.msisdn)
            {
                [lookup3pidsArray addObject:@[kMX3PIDMediumMSISDN, phone.msisdn]];
                [threepids addObject:phone.msisdn];
            }
        }
        
        if (lookup3pidsArray.count > 0)
        {
            MXWeakify(self);
            
            [self.identityRESTClient lookup3pids:lookup3pidsArray
                                         success:^(NSArray *discoveredUsers) {
                                             
                                             MXStrongifyAndReturnIfNil(self);
                                             
                                             // Look for updates
                                             BOOL isUpdated = NO;
                                             
                                             // Consider each discored user
                                             for (NSArray *discoveredUser in discoveredUsers)
                                             {
                                                 // Sanity check
                                                 if (discoveredUser.count == 3)
                                                 {
                                                     NSString *pid = discoveredUser[1];
                                                     NSString *matrixId = discoveredUser[2];
                                                     
                                                     // Remove the 3pid from the requested list
                                                     [threepids removeObject:pid];
                                                     
                                                     NSString *currentMatrixID = [self->matrixIDBy3PID objectForKey:pid];
                                                     
                                                     if (![currentMatrixID isEqualToString:matrixId])
                                                     {
                                                         [self->matrixIDBy3PID setObject:matrixId forKey:pid];
                                                         isUpdated = YES;
                                                     }
                                                 }
                                             }
                                             
                                             // Remove existing information which is not valid anymore
                                             for (NSString *pid in threepids)
                                             {
                                                 if ([self->matrixIDBy3PID objectForKey:pid])
                                                 {
                                                     [self->matrixIDBy3PID removeObjectForKey:pid];
                                                     isUpdated = YES;
                                                 }
                                             }
                                             
                                             if (isUpdated)
                                             {
                                                 [self cacheMatrixIDsDict];
                                                 
                                                 // Update only this contact
                                                 [self updateLocalContactMatrixIDs:contact];
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:contact.contactID userInfo:nil];
                                                 });
                                             }
                                         }
                                         failure:^(NSError *error) {
                                             NSLog(@"[MXKContactManager] lookup3pids failed");
                                             
                                             // try later
                                             dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                 [self updateMatrixIDsForLocalContact:contact];
                                             });
                                         }];
        }
    }
}


- (void)updateMatrixIDsForAllLocalContacts
{
    // Check if the user allowed to sync local contacts.
    // + Check if at least an identity server is available, and if the loading step is not in progress.
    if (![MXKAppSettings standardAppSettings].syncLocalContacts || !self.identityRESTClient || isLocalContactListRefreshing)
    {
        return;
    }
    
    MXWeakify(self);
    
    // Refresh the 3PIDs -> Matrix ID mapping
    dispatch_async(processingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        NSArray* contactsSnapshot = [self->localContactByContactID allValues];
        
        // Retrieve all 3PIDs
        NSMutableArray* threepids = [[NSMutableArray alloc] init];
        NSMutableArray* lookup3pidsArray = [[NSMutableArray alloc] init];
        
        for (MXKContact* contact in contactsSnapshot)
        {
            for (MXKEmail* email in contact.emailAddresses)
            {
                // Not yet added
                if (email.emailAddress.length && [threepids indexOfObject:email.emailAddress] == NSNotFound)
                {
                    [lookup3pidsArray addObject:@[kMX3PIDMediumEmail, email.emailAddress]];
                    [threepids addObject:email.emailAddress];
                }
            }
            
            for (MXKPhoneNumber* phone in contact.phoneNumbers)
            {
                if (phone.msisdn)
                {
                    // Not yet added
                    if ([threepids indexOfObject:phone.msisdn] == NSNotFound)
                    {
                        [lookup3pidsArray addObject:@[kMX3PIDMediumMSISDN, phone.msisdn]];
                        [threepids addObject:phone.msisdn];
                    }
                }
            }
        }
        
        // Update 3PIDs mapping
        if (lookup3pidsArray.count > 0)
        {
            [self.identityRESTClient lookup3pids:lookup3pidsArray
                                         success:^(NSArray *discoveredUsers) {
                                             
                                             MXStrongifyAndReturnIfNil(self);
                                             
                                             [threepids removeAllObjects];
                                             NSMutableArray* userIds = [[NSMutableArray alloc] init];
                                             
                                             // Consider each discored user
                                             for (NSArray *discoveredUser in discoveredUsers)
                                             {
                                                 // Sanity check
                                                 if (discoveredUser.count == 3)
                                                 {
                                                     id threepid = discoveredUser[1];
                                                     id userId = discoveredUser[2];
                                                 
                                                     if ([threepid isKindOfClass:[NSString class]] && [userId isKindOfClass:[NSString class]])
                                                     {
                                                         [threepids addObject:threepid];
                                                         [userIds addObject:userId];
                                                     }
                                                 }
                                             }
                                             
                                             if (userIds.count)
                                             {
                                                 self->matrixIDBy3PID = [[NSMutableDictionary alloc] initWithObjects:userIds forKeys:threepids];
                                             }
                                             else
                                             {
                                                 self->matrixIDBy3PID = nil;
                                             }
                                             
                                             [self cacheMatrixIDsDict];
                                             
                                             [self updateAllLocalContactsMatrixIDs];
                                             
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:nil userInfo:nil];
                                             });
                                             
                                         }
                                         failure:^(NSError *error) {
                                             NSLog(@"[MXKContactManager] lookup3pids failed");
                                             
                                             // try later
                                             dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                 [self updateMatrixIDsForAllLocalContacts];
                                             });
                                         }];
        }
        else
        {
            self->matrixIDBy3PID = nil;
            [self cacheMatrixIDsDict];
        }
    });
}

- (void)reset
{
    matrixIDBy3PID = nil;
    [self cacheMatrixIDsDict];
    
    isLocalContactListRefreshing = NO;
    localContactByContactID = nil;
    localContactsWithMethods = nil;
    splitLocalContacts = nil;
    [self cacheLocalContacts];
    
    matrixContactByContactID = nil;
    matrixContactByMatrixID = nil;
    [self cacheMatrixContacts];
    
    lastSyncDate = nil;
    [self cacheContactBookInfo];
    
    while (mxSessionArray.count) {
        [self removeMatrixSession:mxSessionArray.lastObject];
    }
    mxSessionArray = nil;
    mxEventListeners = nil;
    _identityServer = nil;
    _identityRESTClient = nil;
    
    // warn of the contacts list update
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
}

- (MXKContact*)contactWithContactID:(NSString*)contactID
{
    if ([contactID hasPrefix:kMXKContactLocalContactPrefixId])
    {
        return [localContactByContactID objectForKey:contactID];
    }
    else
    {
        return [matrixContactByContactID objectForKey:contactID];
    }
}

// refresh the international phonenumber of the contacts
- (void)internationalizePhoneNumbers:(NSString*)countryCode
{
    MXWeakify(self);
    
    dispatch_async(processingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        NSArray* contactsSnapshot = [self->localContactByContactID allValues];
        
        for (MXKContact* contact in contactsSnapshot)
        {
            contact.defaultCountryCode = countryCode;
        }
        
        [self cacheLocalContacts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidInternationalizeNotification object:nil userInfo:nil];
        });
    });
}

- (MXKSectionedContacts *)getSectionedContacts:(NSArray*)contactsList
{
    if (!contactsList.count)
    {
        return nil;
    }
    
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    
    int indexOffset = 0;
    
    NSInteger index, sectionTitlesCount = [[collation sectionTitles] count];
    NSMutableArray *tmpSectionsArray = [[NSMutableArray alloc] initWithCapacity:(sectionTitlesCount)];
    
    sectionTitlesCount += indexOffset;
    
    for (index = 0; index < sectionTitlesCount; index++)
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        [tmpSectionsArray addObject:array];
    }
    
    int contactsCount = 0;
    
    for (MXKContact *aContact in contactsList)
    {
        NSInteger section = [collation sectionForObject:aContact collationStringSelector:@selector(displayName)] + indexOffset;
        
        [[tmpSectionsArray objectAtIndex:section] addObject:aContact];
        ++contactsCount;
    }
    
    NSMutableArray *tmpSectionedContactsTitle = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    NSMutableArray *shortSectionsArray = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    
    for (index = indexOffset; index < sectionTitlesCount; index++)
    {
        NSMutableArray *usersArrayForSection = [tmpSectionsArray objectAtIndex:index];
        
        if ([usersArrayForSection count] != 0)
        {
            NSArray* sortedUsersArrayForSection = [collation sortedArrayFromArray:usersArrayForSection collationStringSelector:@selector(displayName)];
            [shortSectionsArray addObject:sortedUsersArrayForSection];
            [tmpSectionedContactsTitle addObject:[[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:(index - indexOffset)]];
        }
    }
    
    return [[MXKSectionedContacts alloc] initWithContacts:shortSectionsArray andTitles:tmpSectionedContactsTitle andCount:contactsCount];
}

- (void)sortAlphabeticallyContacts:(NSMutableArray<MXKContact*> *)contactsArray
{
    NSComparator comparator = ^NSComparisonResult(MXKContact *contactA, MXKContact *contactB) {
        
        if (contactA.sortingDisplayName.length && contactB.sortingDisplayName.length)
        {
            return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
        }
        else if (contactA.sortingDisplayName.length)
        {
            return NSOrderedAscending;
        }
        else if (contactB.sortingDisplayName.length)
        {
            return NSOrderedDescending;
        }
        return [contactA.displayName compare:contactB.displayName options:NSCaseInsensitiveSearch];
    };
    
    // Sort the contacts list
    [contactsArray sortUsingComparator:comparator];
}

- (void)sortContactsByLastActiveInformation:(NSMutableArray<MXKContact*> *)contactsArray
{
    // Sort invitable contacts by last active, with "active now" first.
    // ...and then alphabetically.
    NSComparator comparator = ^NSComparisonResult(MXKContact *contactA, MXKContact *contactB) {
        
        MXUser *userA = [self firstMatrixUserOfContact:contactA];
        MXUser *userB = [self firstMatrixUserOfContact:contactB];
        
        // Non-Matrix-enabled contacts are moved to the end.
        if (userA && !userB)
        {
            return NSOrderedAscending;
        }
        if (!userA && userB)
        {
            return NSOrderedDescending;
        }
        
        // Display active contacts first.
        if (userA.currentlyActive && userB.currentlyActive)
        {
            // Then order by name
            if (contactA.sortingDisplayName.length && contactB.sortingDisplayName.length)
            {
                return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
            }
            else if (contactA.sortingDisplayName.length)
            {
                return NSOrderedAscending;
            }
            else if (contactB.sortingDisplayName.length)
            {
                return NSOrderedDescending;
            }
            return [contactA.displayName compare:contactB.displayName options:NSCaseInsensitiveSearch];
        }
        
        if (userA.currentlyActive && !userB.currentlyActive)
        {
            return NSOrderedAscending;
        }
        if (!userA.currentlyActive && userB.currentlyActive)
        {
            return NSOrderedDescending;
        }
        
        // Finally, compare the lastActiveAgo
        NSUInteger lastActiveAgoA = userA.lastActiveAgo;
        NSUInteger lastActiveAgoB = userB.lastActiveAgo;
        
        if (lastActiveAgoA == lastActiveAgoB)
        {
            return NSOrderedSame;
        }
        else
        {
            return ((lastActiveAgoA > lastActiveAgoB) ? NSOrderedDescending : NSOrderedAscending);
        }
    };
    
    // Sort the contacts list
    [contactsArray sortUsingComparator:comparator];
}

+ (void)requestUserConfirmationForLocalContactsSyncInViewController:(UIViewController *)viewController completionHandler:(void (^)(BOOL))handler
{
    NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];

    [MXKContactManager requestUserConfirmationForLocalContactsSyncWithTitle:[NSBundle mxk_localizedStringForKey:@"local_contacts_access_discovery_warning_title"]
                                                                    message:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"local_contacts_access_discovery_warning"], appDisplayName]
                                                manualPermissionChangeMessage:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"local_contacts_access_not_granted"], appDisplayName]
                                                    showPopUpInViewController:viewController
                                                            completionHandler:handler];
}

+ (void)requestUserConfirmationForLocalContactsSyncWithTitle:(NSString*)title
                                                     message:(NSString*)message
                                           manualPermissionChangeMessage:(NSString*)manualPermissionChangeMessage
                                     showPopUpInViewController:(UIViewController*)viewController
                                             completionHandler:(void (^)(BOOL granted))handler
{
    if ([[MXKAppSettings standardAppSettings] syncLocalContacts])
    {
        handler(YES);
    }
    else
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
                                                    
                                                    [MXKTools checkAccessForContacts:manualPermissionChangeMessage showPopUpInViewController:viewController completionHandler:^(BOOL granted) {
                                                        
                                                        handler(granted);
                                                    }];
                                                    
                                                }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
                                                    
                                                    handler(NO);
                                                    
                                                }]];
        
        
        [viewController presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Internals

- (NSDictionary*)matrixContactsByMatrixIDFromMXSessions:(NSArray<MXSession*>*)mxSessions
{
    // The existing dictionary of contacts will be replaced by this one
    NSMutableDictionary *matrixContactByMatrixID = [[NSMutableDictionary alloc] init];
    for (MXSession *mxSession in mxSessions)
    {
        // Check all existing users
        NSArray *mxUsers = [mxSession.users copy];
        
        for (MXUser *user in mxUsers)
        {
            // Check whether this user has already been added
            if (!matrixContactByMatrixID[user.userId])
            {
                if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats) && mxSession.directRooms[user.userId]))
                {
                    // Check whether a contact is already defined for this id in previous dictionary
                    // (avoid delete and create the same ones, it could save thumbnail downloads).
                    MXKContact* contact = matrixContactByMatrixID[user.userId];
                    if (contact)
                    {
                        contact.displayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                        
                        // Check the avatar change
                        if ((user.avatarUrl || contact.matrixAvatarURL) && ([user.avatarUrl isEqualToString:contact.matrixAvatarURL] == NO))
                        {
                            [contact resetMatrixThumbnail];
                        }
                    }
                    else
                    {
                        contact = [[MXKContact alloc] initMatrixContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andMatrixID:user.userId];
                    }
                    
                    matrixContactByMatrixID[user.userId] = contact;
                }
            }
        }
    }
    
    // Do not make an immutable copy to avoid performance penalty
    return matrixContactByMatrixID;
}

- (void)refreshMatrixContacts
{
    NSArray *mxSessions = self.mxSessions;

    // Check whether at least one session is available
    if (!mxSessions.count)
    {
        matrixContactByMatrixID = nil;
        matrixContactByContactID = nil;
        [self cacheMatrixContacts];

        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
    }
    else if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
    {
        MXWeakify(self);

        BOOL shouldFetchLocalContacts = self->matrixContactByContactID == nil;
        
        dispatch_async(processingQueue, ^{

            MXStrongifyAndReturnIfNil(self);
            
            NSArray *sessions = self.mxSessions;

            NSMutableDictionary *matrixContactsByMatrixID = nil;
            NSMutableDictionary *matrixContactsByContactID = nil;

            if (shouldFetchLocalContacts)
            {
                NSDictionary *cachedMatrixContacts = [self fetchCachedMatrixContacts];

                if (!matrixContactsByContactID)
                {
                    matrixContactsByContactID = [NSMutableDictionary dictionary];
                }
                else
                {
                    matrixContactsByContactID = [cachedMatrixContacts mutableCopy];
                }
            }

            NSDictionary *matrixContacts = [self matrixContactsByMatrixIDFromMXSessions:sessions];

            if (!matrixContacts)
            {
                matrixContactsByMatrixID = [NSMutableDictionary dictionary];
                
                for (MXKContact *contact in matrixContactsByContactID.allValues)
                {
                    matrixContactsByMatrixID[contact.matrixIdentifiers.firstObject] = contact;
                }
            }
            else
            {
                matrixContactsByMatrixID = [matrixContacts mutableCopy];
            }

            for (MXKContact *contact in matrixContactsByMatrixID.allValues)
            {
                matrixContactsByContactID[contact.contactID] = contact;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                MXStrongifyAndReturnIfNil(self);

                // Update the matrix contacts list
                self->matrixContactByMatrixID = matrixContactsByMatrixID;
                self->matrixContactByContactID = matrixContactsByContactID;

                [self cacheMatrixContacts];

                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
            });
        });
    }
}

- (void)updateMatrixContactWithID:(NSString*)matrixId
{
    // Check if a one-to-one room exist for this matrix user in at least one matrix session.
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceDirectChats) && mxSession.directRooms[matrixId]))
        {
            // Retrieve the user object related to this contact
            MXUser* user = [mxSession userWithUserId:matrixId];
            
            // This user may not exist (if the oneToOne room is a pending invitation to him).
            if (user)
            {
                // Update or create a contact for this user
                MXKContact* contact = [matrixContactByMatrixID objectForKey:matrixId];
                BOOL isUpdated = NO;
                
                // already defined
                if (contact)
                {
                    // Check the display name change
                    NSString *userDisplayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                    if (![contact.displayName isEqualToString:userDisplayName])
                    {
                        contact.displayName = userDisplayName;
                        
                        [self cacheMatrixContacts];
                        isUpdated = YES;
                    }
                    
                    // Check the avatar change
                    if ((user.avatarUrl || contact.matrixAvatarURL) && ([user.avatarUrl isEqualToString:contact.matrixAvatarURL] == NO))
                    {
                        [contact resetMatrixThumbnail];
                        isUpdated = YES;
                    }
                }
                else
                {
                    contact = [[MXKContact alloc] initMatrixContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andMatrixID:user.userId];
                    [matrixContactByMatrixID setValue:contact forKey:matrixId];
                    
                    // update the matrix contacts list
                    [matrixContactByContactID setValue:contact forKey:contact.contactID];
                    
                    [self cacheMatrixContacts];
                    isUpdated = YES;
                }
                
                if (isUpdated)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:contact.contactID userInfo:nil];
                }
                
                // Done
                return;
            }
        }
    }
    
    // Here no one-to-one room exist, remove the contact if any
    MXKContact* contact = [matrixContactByMatrixID objectForKey:matrixId];
    if (contact)
    {
        [matrixContactByContactID removeObjectForKey:contact.contactID];
        [matrixContactByMatrixID removeObjectForKey:matrixId];
        
        [self cacheMatrixContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:contact.contactID userInfo:nil];
    }
}

- (void)updateLocalContactMatrixIDs:(MXKContact*) contact
{
    for (MXKPhoneNumber* phoneNumber in contact.phoneNumbers)
    {
        if (phoneNumber.msisdn)
        {
            NSString* matrixID = [matrixIDBy3PID objectForKey:phoneNumber.msisdn];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [phoneNumber setMatrixID:matrixID];
                
            });
        }
    }
    
    for (MXKEmail* email in contact.emailAddresses)
    {
        if (email.emailAddress.length > 0)
        {
            NSString *matrixID = [matrixIDBy3PID objectForKey:email.emailAddress];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [email setMatrixID:matrixID];
                
            });
        }
    }
}

- (void)updateAllLocalContactsMatrixIDs
{
    // Check if the user allowed to sync local contacts
    if (![MXKAppSettings standardAppSettings].syncLocalContacts)
    {
        return;
    }
    
    NSArray* localContacts = [localContactByContactID allValues];
    
    // update the contacts info
    for (MXKContact* contact in localContacts)
    {
        [self updateLocalContactMatrixIDs:contact];
    }
}

- (MXUser*)firstMatrixUserOfContact:(MXKContact*)contact;
{
    MXUser *user = nil;
    
    NSArray *identifiers = contact.matrixIdentifiers;
    if (identifiers.count)
    {
        for (MXSession *session in mxSessionArray)
        {
            user = [session userWithUserId:identifiers.firstObject];
            if (user)
            {
                break;
            }
        }
    }
    
    return user;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"syncLocalContacts" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self refreshLocalContacts];
            
        });
    }
    else if ([@"phonebookCountryCode" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self internationalizePhoneNumbers:[[MXKAppSettings standardAppSettings] phonebookCountryCode]];
            [self refreshLocalContacts];
            
        });
    }
}

#pragma mark - file caches

static NSString *matrixContactsFile = @"matrixContacts";
static NSString *matrixIDsDictFile = @"matrixIDsDict";
static NSString *localContactsFile = @"localContacts";
static NSString *contactsBookInfoFile = @"contacts";

- (NSString*)dataFilePathForComponent:(NSString*)component
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:component];
}

- (void)cacheMatrixContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixContactsFile];
    
    if (matrixContactByContactID && (matrixContactByContactID.count > 0))
    {
        // Switch on processing queue because matrixContactByContactID dictionary may be huge.
        NSDictionary *matrixContactByContactIDCpy = [matrixContactByContactID copy];
        
        dispatch_async(processingQueue, ^{
            
            NSMutableData *theData = [NSMutableData data];
            NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
            
            [encoder encodeObject:matrixContactByContactIDCpy forKey:@"matrixContactByContactID"];
            
            [encoder finishEncoding];
            
            [theData writeToFile:dataFilePath atomically:YES];
            
        });
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (NSDictionary*)fetchCachedMatrixContacts
{
    NSDate *startDate = [NSDate date];
    
    NSString *dataFilePath = [self dataFilePathForComponent:matrixContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    __block NSDictionary *matrixContactByContactID = nil;
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            id object = [decoder decodeObjectForKey:@"matrixContactByContactID"];
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                matrixContactByContactID = object;
            }
            
            [decoder finishDecoding];
        }
        @catch (NSException *exception)
        {
        }
    }
    
    NSLog(@"[MXKContactManager] fetchCachedMatrixContacts : Loaded %tu contacts in %.0fms", matrixContactByContactID.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
    
    return matrixContactByContactID;
}

- (void)cacheMatrixIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixIDsDictFile];
    
    if (matrixIDBy3PID.count)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:matrixIDBy3PID forKey:@"matrixIDsDict"];
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedMatrixIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixIDsDictFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            id object = [decoder decodeObjectForKey:@"matrixIDsDict"];
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                matrixIDBy3PID = [object mutableCopy];
            }
            
            [decoder finishDecoding];
        }
        @catch (NSException *exception)
        {
        }
    }
    
    if (!matrixIDBy3PID)
    {
        matrixIDBy3PID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    if (localContactByContactID && (localContactByContactID.count > 0))
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:localContactByContactID forKey:@"localContactByContactID"];
        
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            id object = [decoder decodeObjectForKey:@"localContactByContactID"];
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                localContactByContactID = [object mutableCopy];
            }
            
            [decoder finishDecoding];
        } @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
    
    if (!localContactByContactID)
    {
        localContactByContactID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    if (lastSyncDate)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:lastSyncDate forKey:@"lastSyncDate"];
        
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            lastSyncDate = [decoder decodeObjectForKey:@"lastSyncDate"];
            
            [decoder finishDecoding];
        } @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
}

@end
