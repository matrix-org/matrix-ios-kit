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

#import "MXKPushRuleCreationTableViewCell.h"

#import "NSBundle+MatrixKit.h"

@interface MXKPushRuleCreationTableViewCell ()
{
    /**
     Snapshot of matrix session rooms used in room picker (in case of MXPushRuleKindRoom)
     */
    NSArray* rooms;
}
@end

@implementation MXKPushRuleCreationTableViewCell

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)setMxPushRuleKind:(MXPushRuleKind)mxPushRuleKind
{
    // TODO
    
    _mxPushRuleKind = mxPushRuleKind;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    rooms = [_mxSession.rooms sortedArrayUsingComparator:^NSComparisonResult(MXRoom* firstRoom, MXRoom* secondRoom) {
        
        // Alphabetic order
        return [firstRoom.state.displayname compare:secondRoom.state.displayname options:NSCaseInsensitiveSearch];
    }];

    return rooms.count;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    MXRoom* room = [rooms objectAtIndex:row];
    return room.state.displayname;
}

//- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
//{
//    // sanity check
//    if ((row >= 0) && (row < rooms.count))
//    {
//        MXRoom* room = [rooms objectAtIndex:row];
//        _inputTextField.text = room.state.displayname;
//    }
//}


@end
