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

#import "MXKAppSettings.h"


// get ISO country name
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

static MXKAppSettings *sharedSettings = nil;

@implementation MXKAppSettings

+ (MXKAppSettings *)sharedSettings {
    @synchronized(self) {
        if(sharedSettings == nil) {
            sharedSettings = [[super allocWithZone:NULL] init];
        }
    }
    return sharedSettings;
}

#pragma  mark - 

-(MXKAppSettings *)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)dealloc {
}

- (void)reset {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"enableInAppNotifications"];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showAllEventsInRoomHistory"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showRedactionsInRoomHistory"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showUnsupportedEventsInRoomHistory"];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"sortRoomMembersUsingLastSeenTime"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showLeftMembersInRoomMemberList"];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"syncLocalContacts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - TODO move this settings in MatrixSessionHandler

- (BOOL)enableInAppNotifications {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"enableInAppNotifications"];
}

- (void)setEnableInAppNotifications:(BOOL)notifications {
//    [[MatrixSDKHandler sharedHandler] enableInAppNotifications:notifications];
    [[NSUserDefaults standardUserDefaults] setBool:notifications forKey:@"enableInAppNotifications"];
}

- (BOOL)showAllEventsInRoomHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showAllEventsInRoomHistory"];
}

- (void)setShowAllEventsInRoomHistory:(BOOL)showAllEventsInRoomHistory {
    [[NSUserDefaults standardUserDefaults] setBool:showAllEventsInRoomHistory forKey:@"showAllEventsInRoomHistory"];
    // Flush and restore Matrix data
//    [[MatrixSDKHandler sharedHandler] reload:NO];
}

- (BOOL)showRedactionsInRoomHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showRedactionsInRoomHistory"];
}

- (void)setShowRedactionsInRoomHistory:(BOOL)showRedactionsInRoomHistory {
    [[NSUserDefaults standardUserDefaults] setBool:showRedactionsInRoomHistory forKey:@"showRedactionsInRoomHistory"];
}

- (BOOL)showUnsupportedEventsInRoomHistory {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showUnsupportedEventsInRoomHistory"];
}

- (void)setShowUnsupportedEventsInRoomHistory:(BOOL)showUnsupportedEventsInRoomHistory {
    [[NSUserDefaults standardUserDefaults] setBool:showUnsupportedEventsInRoomHistory forKey:@"showUnsupportedEventsInRoomHistory"];
}

- (BOOL)sortRoomMembersUsingLastSeenTime {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"sortRoomMembersUsingLastSeenTime"];
}

- (void)setSortRoomMembersUsingLastSeenTime:(BOOL)sortRoomMembersUsingLastSeenTime {
    [[NSUserDefaults standardUserDefaults] setBool:sortRoomMembersUsingLastSeenTime forKey:@"sortRoomMembersUsingLastSeenTime"];
}

- (BOOL)showLeftMembersInRoomMemberList {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"showLeftMembersInRoomMemberList"];
}

- (void)setShowLeftMembersInRoomMemberList:(BOOL)showLeftMembersInRoomMemberList {
    [[NSUserDefaults standardUserDefaults] setBool:showLeftMembersInRoomMemberList forKey:@"showLeftMembersInRoomMemberList"];
}

- (BOOL)syncLocalContacts {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"syncLocalContacts"];
}

- (void)setSyncLocalContacts:(BOOL)syncLocalContacts {
    [[NSUserDefaults standardUserDefaults] setBool:syncLocalContacts forKey:@"syncLocalContacts"];
}

- (NSString*)phonebookCountryCode {
    NSString* res = [[NSUserDefaults standardUserDefaults] stringForKey:@"phonebookCountryCode"];
    
    // does not exist : try to get the SIM card information
    if (!res) {
        // get the current MCC
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netInfo subscriberCellularProvider];
        
        if (carrier) {
            res = [[carrier isoCountryCode] uppercaseString];
            
            if (res) {
                [self setPhonebookCountryCode:res];
            }
        }
    }
    
    return res;
}

- (void)setPhonebookCountryCode:(NSString *)phonebookCountryCode{
    [[NSUserDefaults standardUserDefaults] setObject:phonebookCountryCode forKey:@"phonebookCountryCode"];
}

@end
