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

#import "MXKRoomCreationView.h"

@interface MXKRoomCreationView ()
{
    MXKAlert *mxSessionPicker;
    
    // Array of homeserver suffix (NSString instance)
    NSMutableArray *homeServerSuffixArray;
}

@end

@implementation MXKRoomCreationView
@synthesize inputAccessoryView;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomCreationView class])
                          bundle:[NSBundle bundleForClass:[MXKRoomCreationView class]]];
}

+ (instancetype)roomCreationView
{
    if ([[self class] nib])
    {
        return [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
    }
    else
    {
        return [[self alloc] init];
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Add observer to keep align text fields
    [_roomNameLabel  addObserver:self forKeyPath:@"text" options:0 context:nil];
    [_roomAliasLabel  addObserver:self forKeyPath:@"text" options:0 context:nil];
    [_participantsLabel  addObserver:self forKeyPath:@"text" options:0 context:nil];
    [self alignTextFields];
    
    // Finalize setup
    [self setTranslatesAutoresizingMaskIntoConstraints: NO];
    
    // Add an accessory view to the text views in order to retrieve keyboard view.
    inputAccessoryView = [[UIView alloc] initWithFrame:CGRectZero];
    _roomNameTextField.inputAccessoryView = inputAccessoryView;
    _roomAliasTextField.inputAccessoryView = inputAccessoryView;
    _participantsTextField.inputAccessoryView = inputAccessoryView;
}

- (void)dealloc
{
    [self destroy];
    
    inputAccessoryView = nil;
}

- (void)setRoomNameFieldHidden:(BOOL)roomNameFieldHidden
{
    _roomNameFieldHidden = _roomNameTextField.hidden = _roomNameLabel.hidden = roomNameFieldHidden;
    
    if (roomNameFieldHidden)
    {
        _roomAliasFieldTopConstraint.constant -= _roomNameTextField.frame.size.height + 8;
        _participantsFieldTopConstraint.constant -= _roomNameTextField.frame.size.height + 8;
        _createRoomBtnTopConstraint.constant -= _roomNameTextField.frame.size.height + 8;
    }
    else
    {
        _roomAliasFieldTopConstraint.constant += _roomNameTextField.frame.size.height + 8;
        _participantsFieldTopConstraint.constant += _roomNameTextField.frame.size.height + 8;
        _createRoomBtnTopConstraint.constant += _roomNameTextField.frame.size.height + 8;
    }
    
    [self alignTextFields];
}

- (void)setRoomAliasFieldHidden:(BOOL)roomAliasFieldHidden
{
    _roomAliasFieldHidden = _roomAliasTextField.hidden = _roomAliasLabel.hidden = roomAliasFieldHidden;
    
    if (roomAliasFieldHidden)
    {
        _participantsFieldTopConstraint.constant -= _roomAliasTextField.frame.size.height + 8;
        _createRoomBtnTopConstraint.constant -= _roomAliasTextField.frame.size.height + 8;
    }
    else
    {
        _participantsFieldTopConstraint.constant += _roomAliasTextField.frame.size.height + 8;
        _createRoomBtnTopConstraint.constant += _roomAliasTextField.frame.size.height + 8;
    }
    
    [self alignTextFields];
}

- (void)setParticipantsFieldHidden:(BOOL)participantsFieldHidden
{
    _participantsFieldHidden = _participantsTextField.hidden = _participantsLabel.hidden = participantsFieldHidden;
    
    if (participantsFieldHidden)
    {
        _createRoomBtnTopConstraint.constant -= _participantsTextField.frame.size.height + 8;
    }
    else
    {
        _createRoomBtnTopConstraint.constant += _participantsTextField.frame.size.height + 8;
    }
    
    [self alignTextFields];
}

- (CGFloat)actualFrameHeight
{
    return (_createRoomBtnTopConstraint.constant + _createRoomBtn.frame.size.height + 8);
}

- (void)setMxSessions:(NSArray *)mxSessions
{
    _mxSessions = mxSessions;
    
    if (mxSessions.count)
    {
        homeServerSuffixArray = [NSMutableArray array];
        
        for (MXSession *mxSession in mxSessions)
        {
            NSString *homeserverSuffix = mxSession.matrixRestClient.homeserverSuffix;
            if (homeserverSuffix && [homeServerSuffixArray indexOfObject:homeserverSuffix] == NSNotFound)
            {
                [homeServerSuffixArray addObject:homeserverSuffix];
            }
        }
    }
    else
    {
        homeServerSuffixArray = nil;
    }
    
    // Update alias placeholder in room creation section
    if (homeServerSuffixArray.count == 1)
    {
        _roomAliasTextField.placeholder = [NSString stringWithFormat:@"(e.g. #foo%@)", homeServerSuffixArray.firstObject];
    }
    else
    {
        _roomAliasTextField.placeholder = @"(e.g. #foo:example.org)";
    }
}

- (void)dismissKeyboard
{
    // Hide the keyboard
    [_roomNameTextField resignFirstResponder];
    [_roomAliasTextField resignFirstResponder];
    [_participantsTextField resignFirstResponder];
}

- (void)destroy
{
    self.mxSessions = nil;
    
    // Remove observers
    [_roomNameLabel  removeObserver:self forKeyPath:@"text"];
    [_roomAliasLabel  removeObserver:self forKeyPath:@"text"];
    [_participantsLabel  removeObserver:self forKeyPath:@"text"];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    // UIView will be "transparent" for touch events if we return NO
    return YES;
}

#pragma mark - Internal methods

- (void)alignTextFields
{
    CGFloat maxLabelLenght = 0;
    
    if (!_roomNameLabel.hidden)
    {
        maxLabelLenght = _roomNameLabel.frame.size.width;
    }
    if (!_roomAliasLabel.hidden && maxLabelLenght < _roomAliasLabel.frame.size.width)
    {
        maxLabelLenght = _roomAliasLabel.frame.size.width;
    }
    if (!_participantsLabel.hidden && maxLabelLenght < _participantsLabel.frame.size.width)
    {
        maxLabelLenght = _participantsLabel.frame.size.width;
    }
    
    // Update textField left constraint by adding marging
    _textFieldLeftConstraint.constant = maxLabelLenght + (2 * 8);
    
    [self layoutIfNeeded];
}

- (NSString*)alias
{
    // Extract alias name from alias text field
    NSString *alias = _roomAliasTextField.text;
    if (alias.length)
    {
        // Remove '#' character
        alias = [alias substringFromIndex:1];
        
        NSString *actualAlias = nil;
        for (NSString *homeServerSuffix in homeServerSuffixArray)
        {
            // Remove homeserver suffix
            NSRange range = [alias rangeOfString:homeServerSuffix];
            if (range.location != NSNotFound)
            {
                actualAlias = [alias stringByReplacingCharactersInRange:range withString:@""];
                break;
            }
        }
        
        if (actualAlias)
        {
            alias = actualAlias;
        }
        else
        {
            NSLog(@"[MXKRoomCreationTableVC] Wrong room alias has been set (%@)", _roomAliasTextField.text);
            alias = nil;
        }
    }
    
    if (! alias.length)
    {
        alias = nil;
    }
    
    return alias;
}

- (NSArray*)participantsList
{
    NSMutableArray *participants = [NSMutableArray array];
    
    if (_participantsTextField.text.length)
    {
        NSArray *components = [_participantsTextField.text componentsSeparatedByString:@";"];
        
        for (NSString *component in components)
        {
            // Remove white space from both ends
            NSString *user = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (user.length > 1 && [user hasPrefix:@"@"])
            {
                [participants addObject:user];
            }
        }
    }
    
    if (participants.count == 0)
    {
        participants = nil;
    }
    
    return participants;
}

- (void)selectMatrixSession:(void (^)(MXSession *selectedSession))onSelection
{
    if (_mxSessions.count == 1)
    {
        if (onSelection)
        {
            onSelection(_mxSessions.firstObject);
        }
    }
    else if (_mxSessions.count > 1)
    {
        if (mxSessionPicker)
        {
            [mxSessionPicker dismiss:NO];
        }
        
        mxSessionPicker = [[MXKAlert alloc] initWithTitle:@"Select an account" message:nil style:MXKAlertStyleActionSheet];
        
        __weak typeof(self) weakSelf = self;
        for(MXSession *mxSession in _mxSessions)
        {
            [mxSessionPicker addActionWithTitle:mxSession.myUser.userId style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->mxSessionPicker = nil;
                if (onSelection)
                {
                    onSelection(mxSession);
                }
            }];
        }
        
        mxSessionPicker.cancelButtonIndex = [mxSessionPicker addActionWithTitle:@"Cancel" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->mxSessionPicker = nil;
        }];
        
        mxSessionPicker.sourceView = self;
        
        if (self.delegate)
        {
            [self.delegate roomCreationView:self presentMXKAlert:mxSessionPicker];
        }
    }
}

#pragma mark - UITextField delegate

- (IBAction)textFieldEditingChanged:(id)sender
{
    // Update Create Room button
    NSString *roomName = _roomNameTextField.text;
    NSString *roomAlias = _roomAliasTextField.text;
    NSString *participants = _participantsTextField.text;
    
    if (roomName.length || roomAlias.length || participants.length)
    {
        _createRoomBtn.enabled = YES;
    }
    else
    {
        _createRoomBtn.enabled = NO;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == _participantsTextField)
    {
        if (textField.text.length == 0)
        {
            textField.text = @"@";
        }
    }
    else if (textField == _roomAliasTextField)
    {
        if (textField.text.length == 0)
        {
            textField.text = @"#";
        }
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == _roomAliasTextField)
    {
        if (homeServerSuffixArray.count == 1)
        {
            // Check whether homeserver suffix should be added
            NSRange range = [textField.text rangeOfString:@":"];
            if (range.location == NSNotFound)
            {
                textField.text = [textField.text stringByAppendingString:homeServerSuffixArray.firstObject];
            }
        }
        
        // Check whether the alias is valid
        if (!self.alias)
        {
            // reset text field
            textField.text = nil;
            [self textFieldDidEndEditing:nil];
        }
    }
    else if (textField == _participantsTextField)
    {
        NSArray *participants = self.participantsList;
        textField.text = [participants componentsJoinedByString:@"; "];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Auto complete participant IDs
    if (textField == _participantsTextField)
    {
        // Add @ if none
        if (!textField.text.length || textField.text.length == range.length)
        {
            if ([string hasPrefix:@"@"] == NO)
            {
                textField.text = [NSString stringWithFormat:@"@%@",string];
                // Update Create button status
                [self textFieldDidEndEditing:nil];
                return NO;
            }
        }
        else if (range.location == textField.text.length)
        {
            if ([string isEqualToString:@";"])
            {
                // Add '@' character
                textField.text = [textField.text stringByAppendingString:@"; @"];
                // Update Create button status
                [self textFieldDidEndEditing:nil];
                return NO;
            }
        }
    }
    else if (textField == _roomAliasTextField)
    {
        // Add # if none
        if (!textField.text.length || textField.text.length == range.length)
        {
            if ([string hasPrefix:@"#"] == NO)
            {
                if ([string isEqualToString:@":"] && homeServerSuffixArray.count == 1)
                {
                    textField.text = [NSString stringWithFormat:@"#%@",homeServerSuffixArray.firstObject];
                }
                else
                {
                    textField.text = [NSString stringWithFormat:@"#%@",string];
                }
                // Update Create button status
                [self textFieldDidEndEditing:nil];
                return NO;
            }
        }
        else if (homeServerSuffixArray.count == 1)
        {
            // Add homeserver automatically when user adds ':' at the end
            if (range.location == textField.text.length && [string isEqualToString:@":"])
            {
                textField.text = [textField.text stringByAppendingString:homeServerSuffixArray.firstObject];
                // Update Create button status
                [self textFieldDidEndEditing:nil];
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*) textField
{
    // "Done" key has been pressed
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Actions

- (IBAction)onButtonPressed:(id)sender
{
    [self dismissKeyboard];
    
    // Handle multi-sessions here
    [self selectMatrixSession:^(MXSession *selectedSession)
    {
        if (sender == _createRoomBtn)
        {
            // Disable button to prevent multiple request
            _createRoomBtn.enabled = NO;
            
            NSString *roomName = _roomNameTextField.text;
            if (! roomName.length)
            {
                roomName = nil;
            }
            
            // Create new room
            [selectedSession createRoom:roomName
                             visibility:(_roomVisibilityControl.selectedSegmentIndex == 0) ? kMXRoomVisibilityPublic : kMXRoomVisibilityPrivate
                              roomAlias:self.alias
                                  topic:nil
                                success:^(MXRoom *room) {
                // Check whether some users must be invited
                NSArray *invitedUsers = self.participantsList;
                for (NSString *userId in invitedUsers)
                {
                    [room inviteUser:userId success:^{
                        NSLog(@"[MXKRoomCreationTableVC] %@ has been invited (roomId: %@)", userId, room.state.roomId);
                    } failure:^(NSError *error)
                    {
                        NSLog(@"[MXKRoomCreationTableVC] %@ invitation failed (roomId: %@): %@", userId, room.state.roomId, error);
                        // TODO GFO Alert user
                        //                                            [[AppDelegate theDelegate] showErrorAsAlert:error];
                    }];
                }
                
                // Reset text fields
                _roomNameTextField.text = nil;
                _roomAliasTextField.text = nil;
                _participantsTextField.text = nil;
                
                if (self.delegate)
                {
                    // Open created room
                    [self.delegate roomCreationView:self showRoom:room.state.roomId withMatrixSession:selectedSession];
                }
            } failure:^(NSError *error) {
                _createRoomBtn.enabled = YES;
                NSLog(@"[MXKRoomCreationTableVC] Create room (%@ %@ (%@)) failed: %@", _roomNameTextField.text, self.alias, (_roomVisibilityControl.selectedSegmentIndex == 0) ? @"Public":@"Private", error);
                // TODO GFO Alert user
                //                                    [[AppDelegate theDelegate] showErrorAsAlert:error];
            }];
        }
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Check whether one label has been updated
    if ([@"text" isEqualToString:keyPath] && (object == _roomNameLabel || object == _roomAliasLabel || object == _participantsLabel))
    {
        // Update left constraint of the text fields
        [object sizeToFit];
        [self alignTextFields];
    }
}

@end
