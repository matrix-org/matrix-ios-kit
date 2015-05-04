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

#import "MXKTools.h"


// get ISO country name
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

static MXKAppSettings *standardAppSettings = nil;

@implementation MXKAppSettings
@synthesize enableInAppNotifications;
@synthesize showAllEventsInRoomHistory, showRedactionsInRoomHistory, showUnsupportedEventsInRoomHistory;
@synthesize showLeftMembersInRoomMemberList, sortRoomMembersUsingLastSeenTime;
@synthesize syncLocalContacts, phonebookCountryCode;
@synthesize presenceColorForOnlineUser, presenceColorForUnavailableUser, presenceColorForOfflineUser;

+ (MXKAppSettings *)standardAppSettings {
    @synchronized(self) {
        if(standardAppSettings == nil) {
            standardAppSettings = [[super allocWithZone:NULL] init];
        }
    }
    return standardAppSettings;
}

#pragma  mark - 

-(instancetype)init {
    if (self = [super init]) {
        
        // Use presence to sort room members by default
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"sortRoomMembersUsingLastSeenTime"]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"sortRoomMembersUsingLastSeenTime"];
        }
        sortRoomMembersUsingLastSeenTime = YES;
        
        presenceColorForOnlineUser = [UIColor greenColor];
        presenceColorForUnavailableUser = [UIColor yellowColor];
        presenceColorForOfflineUser = [UIColor redColor];
    }
    return self;
}

- (void)dealloc {
}

- (void)reset {
    
    if (self == [MXKAppSettings standardAppSettings]) {
        // Flush shared user defaults
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"enableInAppNotifications"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showAllEventsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showRedactionsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showUnsupportedEventsInRoomHistory"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"sortRoomMembersUsingLastSeenTime"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showLeftMembersInRoomMemberList"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"syncLocalContacts"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"phonebookCountryCode"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOnlineUser"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForUnavailableUser"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOfflineUser"];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        enableInAppNotifications = NO;
        
        showAllEventsInRoomHistory = NO;
        showRedactionsInRoomHistory = NO;
        showUnsupportedEventsInRoomHistory = NO;
        
        sortRoomMembersUsingLastSeenTime = YES;
        showLeftMembersInRoomMemberList = NO;
        
        syncLocalContacts = NO;
        phonebookCountryCode = nil;
        
        presenceColorForOnlineUser = [UIColor greenColor];
        presenceColorForUnavailableUser = [UIColor yellowColor];
        presenceColorForOfflineUser = [UIColor redColor];
    }
}

#pragma mark -

- (BOOL)enableInAppNotifications {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"enableInAppNotifications"];
    } else {
        return enableInAppNotifications;
    }
}

- (void)setEnableInAppNotifications:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"enableInAppNotifications"];
    } else {
        enableInAppNotifications = boolValue;
    }
}

#pragma mark - Room display

- (BOOL)showAllEventsInRoomHistory {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showAllEventsInRoomHistory"];
    } else {
        return showAllEventsInRoomHistory;
    }
}

- (void)setShowAllEventsInRoomHistory:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showAllEventsInRoomHistory"];
    } else {
        showAllEventsInRoomHistory = boolValue;
    }
}

- (BOOL)showRedactionsInRoomHistory {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showRedactionsInRoomHistory"];
    } else {
        return showRedactionsInRoomHistory;
    }
}

- (void)setShowRedactionsInRoomHistory:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showRedactionsInRoomHistory"];
    } else {
        showRedactionsInRoomHistory = boolValue;
    }
}

- (BOOL)showUnsupportedEventsInRoomHistory {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showUnsupportedEventsInRoomHistory"];
    } else {
        return showUnsupportedEventsInRoomHistory;
    }
}

- (void)setShowUnsupportedEventsInRoomHistory:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showUnsupportedEventsInRoomHistory"];
    } else {
        showUnsupportedEventsInRoomHistory = boolValue;
    }
}

#pragma mark - Room members

- (BOOL)sortRoomMembersUsingLastSeenTime {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"sortRoomMembersUsingLastSeenTime"];
    } else {
        return sortRoomMembersUsingLastSeenTime;
    }
}

- (void)setSortRoomMembersUsingLastSeenTime:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"sortRoomMembersUsingLastSeenTime"];
    } else {
        sortRoomMembersUsingLastSeenTime = boolValue;
    }
}

- (BOOL)showLeftMembersInRoomMemberList {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showLeftMembersInRoomMemberList"];
    } else {
        return showLeftMembersInRoomMemberList;
    }
}

- (void)setShowLeftMembersInRoomMemberList:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showLeftMembersInRoomMemberList"];
    } else {
        showLeftMembersInRoomMemberList = boolValue;
    }
}

#pragma mark - Contacts

- (BOOL)syncLocalContacts {
    if (self == [MXKAppSettings standardAppSettings]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"syncLocalContacts"];
    } else {
        return syncLocalContacts;
    }
}

- (void)setSyncLocalContacts:(BOOL)boolValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"syncLocalContacts"];
    } else {
        syncLocalContacts = boolValue;
    }
}

- (NSString*)phonebookCountryCode {
    NSString* res = phonebookCountryCode;
    
    if (self == [MXKAppSettings standardAppSettings]) {
        res = [[NSUserDefaults standardUserDefaults] stringForKey:@"phonebookCountryCode"];
    }
    
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

- (void)setPhonebookCountryCode:(NSString *)stringValue {
    if (self == [MXKAppSettings standardAppSettings]) {
        [[NSUserDefaults standardUserDefaults] setObject:stringValue forKey:@"phonebookCountryCode"];
    } else {
        phonebookCountryCode = stringValue;
    }
}

#pragma mark - Matrix users

- (UIColor*)presenceColorForOnlineUser {
    UIColor *color = presenceColorForOnlineUser;
    
    if (self == [MXKAppSettings standardAppSettings]) {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForOnlineUser"];
        if (rgbValue) {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        } else {
            color = [UIColor greenColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForOnlineUser:(UIColor*)color {
    if (self == [MXKAppSettings standardAppSettings]) {
        if (color) {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForOnlineUser"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOnlineUser"];
        }
    } else {
        presenceColorForOnlineUser = color ? color : [UIColor greenColor];
    }
}

- (UIColor*)presenceColorForUnavailableUser {
    UIColor *color = presenceColorForUnavailableUser;
    
    if (self == [MXKAppSettings standardAppSettings]) {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForUnavailableUser"];
        if (rgbValue) {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        } else {
            color = [UIColor yellowColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForUnavailableUser:(UIColor*)color {
    if (self == [MXKAppSettings standardAppSettings]) {
        if (color) {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForUnavailableUser"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForUnavailableUser"];
        }
    } else {
        presenceColorForUnavailableUser = color ? color : [UIColor yellowColor];
    }
}

- (UIColor*)presenceColorForOfflineUser {
    UIColor *color = presenceColorForOfflineUser;
    
    if (self == [MXKAppSettings standardAppSettings]) {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForOfflineUser"];
        if (rgbValue) {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        } else {
            color = [UIColor redColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForOfflineUser:(UIColor *)color {
    if (self == [MXKAppSettings standardAppSettings]) {
        if (color) {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForOfflineUser"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOfflineUser"];
        }
    } else {
        presenceColorForOfflineUser = color ? color : [UIColor redColor];
    }
}

@end
