/*
 Copyright 2018 New Vector Ltd

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

#import "MXKRoomNameStringLocalizations.h"

#import "NSBundle+MatrixKit.h"

#import "MXKSwiftHeader.h"

@interface MXKRoomNameStringLocalizations ()

@property (nonatomic, copy) NSString *emptyRoom;
@property (nonatomic, copy) NSString *twoMembers;
@property (nonatomic, copy) NSString *moreThanTwoMembers;
@property (nonatomic, copy) NSString *allOtherParticipantsLeft;

@end

@implementation MXKRoomNameStringLocalizations

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _emptyRoom = [MatrixKitL10n roomDisplaynameEmptyRoom];
        _twoMembers = [NSBundle mxk_localizedStringForKey:@"room_displayname_two_members"];
        _moreThanTwoMembers = [NSBundle mxk_localizedStringForKey:@"room_displayname_more_than_two_members"];
        _allOtherParticipantsLeft = [NSBundle mxk_localizedStringForKey:@"room_displayname_all_other_participants_left"];
    }
    return self;
}

@end
