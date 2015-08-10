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

#import "MXKRoomTitleView.h"

#import "MXKConstants.h"

#import "NSBundle+MatrixKit.h"

@interface MXKRoomTitleView ()
{
    id roomListener;
}
@end

@implementation MXKRoomTitleView
@synthesize inputAccessoryView;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomTitleView class])
                          bundle:[NSBundle bundleForClass:[MXKRoomTitleView class]]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setTranslatesAutoresizingMaskIntoConstraints: NO];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Add an accessory view to the text view in order to retrieve keyboard view.
    inputAccessoryView = [[UIView alloc] initWithFrame:CGRectZero];
    self.displayNameTextField.inputAccessoryView = inputAccessoryView;
    
    self.displayNameTextField.enabled = NO;
    self.displayNameTextField.returnKeyType = UIReturnKeyDone;
    self.displayNameTextField.hidden = YES;
}

+ (instancetype)roomTitleView
{
    return [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
}

- (void)dealloc
{
    inputAccessoryView = nil;
    
    [self destroy];
}

- (void)refreshDisplay
{
    if (_mxRoom)
    {
        // replace empty string by nil : avoid having the placeholder 'Room name" when there is no displayname
        self.displayNameTextField.text = (_mxRoom.state.displayname.length) ? _mxRoom.state.displayname : nil;
    }
    else
    {
        self.displayNameTextField.text = [NSBundle mxk_localizedStringForKey:@"room_please_select"];
        self.displayNameTextField.enabled = NO;
    }
    self.displayNameTextField.hidden = NO;
}

- (void)destroy
{
    self.delegate = nil;
    self.mxRoom = nil;
}

- (void)dismissKeyboard
{
    // Hide the keyboard
    [self.displayNameTextField resignFirstResponder];
}

#pragma mark -

- (void)setMxRoom:(MXRoom *)mxRoom
{
    // Check whether the room is actually changed
    if (_mxRoom != mxRoom)
    {
        // Remove potential listener
        if (roomListener && _mxRoom)
        {
            [_mxRoom removeListener:roomListener];
            roomListener = nil;
        }
        
        if (mxRoom)
        {
            // Register a listener to handle messages related to room name
            roomListener = [mxRoom listenToEventsOfTypes:@[kMXEventTypeStringRoomName, kMXEventTypeStringRoomAliases, kMXEventTypeStringRoomMember]
                                                 onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
            {
                // Consider only live events
                if (direction == MXEventDirectionForwards)
                {
                    
                    // In case of room member change, check whether the text field is editing before refreshing title view
                    if (event.eventType != MXEventTypeRoomMember || !self.isEditing)
                    {
                        [self refreshDisplay];
                    }
                }
            }];
        }
        _mxRoom = mxRoom;
    }
    // Force refresh
    [self refreshDisplay];
}

- (void)setEditable:(BOOL)editable
{
    self.displayNameTextField.enabled = editable;
}

- (BOOL)isEditing
{
    return self.displayNameTextField.isEditing;
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    NSString *alertMsg = nil;
    
    if (textField == self.displayNameTextField)
    {
        // Check whether the user has enough power to rename the room
        MXRoomPowerLevels *powerLevels = [_mxRoom.state powerLevels];
        NSUInteger userPowerLevel = [powerLevels powerLevelOfUserWithUserID:_mxRoom.mxSession.myUser.userId];
        if (userPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomName])
        {
            // Only the room name is edited here, update the text field with the room name
            textField.text = _mxRoom.state.name;
            textField.backgroundColor = [UIColor whiteColor];
        }
        else
        {
            alertMsg = [NSBundle mxk_localizedStringForKey:@"room_error_name_edition_not_authorized"];
        }
    }
    
    if (alertMsg)
    {
        // Alert user
        __weak typeof(self) weakSelf = self;
        if (currentAlert)
        {
            [currentAlert dismiss:NO];
        }
        currentAlert = [[MXKAlert alloc] initWithTitle:nil message:alertMsg style:MXKAlertStyleAlert];
        currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->currentAlert = nil;
        }];
        [self.delegate roomTitleView:self presentMXKAlert:currentAlert];
        return NO;
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.displayNameTextField)
    {
        textField.backgroundColor = [UIColor clearColor];
        
        NSString *roomName = textField.text;
        if ((roomName.length || _mxRoom.state.name.length) && [roomName isEqualToString:_mxRoom.state.name] == NO)
        {
            if ([self.delegate respondsToSelector:@selector(roomTitleView:isSaving:)])
            {
                [self.delegate roomTitleView:self isSaving:YES];
            }
            
            __weak typeof(self) weakSelf = self;
            [_mxRoom setName:roomName success:^{
                
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if ([strongSelf.delegate respondsToSelector:@selector(roomTitleView:isSaving:)])
                {
                    [strongSelf.delegate roomTitleView:strongSelf isSaving:NO];
                }
                
                // Refresh title display
                textField.text = strongSelf.mxRoom.state.displayname;
                
            } failure:^(NSError *error) {
                
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if ([strongSelf.delegate respondsToSelector:@selector(roomTitleView:isSaving:)])
                {
                    [strongSelf.delegate roomTitleView:strongSelf isSaving:NO];
                }
                
                // Revert change
                textField.text = strongSelf.mxRoom.state.displayname;
                NSLog(@"[MXKRoomTitleView] Rename room failed: %@", error);
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                
            }];
        }
        else
        {
            // No change on room name, restore title with room displayName
            textField.text = _mxRoom.state.displayname;
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField*) textField
{
    // "Done" key has been pressed
    [textField resignFirstResponder];
    return YES;
}

@end
