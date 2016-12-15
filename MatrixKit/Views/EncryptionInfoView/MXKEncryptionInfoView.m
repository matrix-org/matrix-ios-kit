/*
 Copyright 2016 OpenMarket Ltd
 
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

#import "MXKEncryptionInfoView.h"

#import "NSBundle+MatrixKit.h"

#import "MXKConstants.h"

static NSAttributedString *verticalWhitespace = nil;

@interface MXKEncryptionInfoView ()
{
    /**
     The displayed event
     */
    MXEvent *mxEvent;
    
    /**
     The matrix session.
     */
    MXSession *mxSession;
    
    /**
     The event device info
     */
    MXDeviceInfo *mxDeviceInfo;
    
    /**
     Current request in progress.
     */
    MXHTTPOperation *mxCurrentOperation;
    
}
@end

@implementation MXKEncryptionInfoView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _defaultTextColor = [UIColor blackColor];
    
    // Localize string
    [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"ok"] forState:UIControlStateNormal];
    [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"ok"] forState:UIControlStateHighlighted];
    
    [_confirmVerifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_verify_ok"] forState:UIControlStateNormal];
    [_confirmVerifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_verify_ok"] forState:UIControlStateHighlighted];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Scroll to the top the text view content
    self.textView.contentOffset = CGPointZero;
}

- (void)removeFromSuperview
{
    if (mxCurrentOperation)
    {
        [mxCurrentOperation cancel];
        mxCurrentOperation = nil;
    }
    
    [super removeFromSuperview];
}

- (instancetype)initWithEvent:(MXEvent*)event andMatrixSession:(MXSession*)session
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKEncryptionInfoView class]] loadNibNamed:NSStringFromClass([MXKEncryptionInfoView class])
                                                                                      owner:nil
                                                                                    options:nil];
    self = nibViews.firstObject;
    if (self)
    {
        mxEvent = event;
        mxSession = session;
        mxDeviceInfo = nil;
        
        [self setTranslatesAutoresizingMaskIntoConstraints: NO];
        
        [self updateTextViewText];
    }
    
    return self;
}

- (instancetype)initWithDeviceInfo:(MXDeviceInfo*)deviceInfo andMatrixSession:(MXSession*)session
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKEncryptionInfoView class]] loadNibNamed:NSStringFromClass([MXKEncryptionInfoView class])
                                                                                        owner:nil
                                                                                      options:nil];
    self = nibViews.firstObject;
    if (self)
    {
        mxEvent = nil;
        mxDeviceInfo = deviceInfo;
        mxSession = session;
        
        [self setTranslatesAutoresizingMaskIntoConstraints: NO];
        
        [self updateTextViewText];
    }
    
    return self;
}

- (void)dealloc
{
    mxEvent = nil;
    mxSession = nil;
    mxDeviceInfo = nil;
}

#pragma mark - 

- (void)updateTextViewText
{
    // Prepare the text view content
    NSMutableAttributedString *textViewAttributedString = [[NSMutableAttributedString alloc]
                                                           initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_title"]
                                                           attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                        NSFontAttributeName: [UIFont boldSystemFontOfSize:17]}];

    if (mxEvent)
    {
        NSString *senderId = mxEvent.sender;
        
        if (mxSession && mxSession.crypto && !mxDeviceInfo)
        {
            mxDeviceInfo = [mxSession.crypto eventDeviceInfo:mxEvent];
            
            if (!mxDeviceInfo)
            {
#ifdef MX_CRYPTO
                // Trigger a server request to get the device information for the event sender
                mxCurrentOperation = [mxSession.crypto downloadKeys:@[senderId] success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap) {
                    
                    mxCurrentOperation = nil;
                    
                    // Sanity check: check whether some device information has been retrieved.
                    mxDeviceInfo = [mxSession.crypto eventDeviceInfo:mxEvent];
                    if (mxDeviceInfo)
                    {
                        [self updateTextViewText];
                    }
                    
                } failure:^(NSError *error) {
                    
                    mxCurrentOperation = nil;
                    
                    NSLog(@"[MXKEncryptionInfoView] Crypto failed to download device info for user: %@", mxEvent.sender);
                    
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
#endif
            }
        }
        
        // Event information
        NSMutableAttributedString *eventInformationString = [[NSMutableAttributedString alloc]
                                                             initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event"]
                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                          NSFontAttributeName: [UIFont boldSystemFontOfSize:15]}];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        NSString *senderKey = mxEvent.senderKey;
        NSString *claimedKey = mxEvent.keysClaimed[@"ed25519"];
        NSString *algorithm = mxEvent.wireContent[@"algorithm"];
        NSString *sessionId = mxEvent.wireContent[@"session_id"];
        
        NSString *decryptionError;
        if (mxEvent.decryptionError)
        {
            decryptionError = [NSString stringWithFormat:@"** %@ **", mxEvent.decryptionError.localizedDescription];
        }
        
        if (!senderKey.length)
        {
            senderKey = [NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_none"];
        }
        if (!claimedKey.length)
        {
            claimedKey = [NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_none"];
        }
        if (!algorithm.length)
        {
            algorithm = [NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_unencrypted"];
        }
        if (!sessionId.length)
        {
            sessionId = [NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_none"];
        }
        
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_user_id"]                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:senderId
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_identity_key"]
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:senderKey
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_fingerprint_key"]
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:claimedKey
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_algorithm"]
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:algorithm
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        if (decryptionError.length)
        {
            [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                            initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_decryption_error"]
                                                            attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                         NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
            [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                            initWithString:decryptionError
                                                            attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                         NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
            [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        }
        
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_event_session_id"]
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                        initWithString:sessionId
                                                        attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [eventInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [textViewAttributedString appendAttributedString:eventInformationString];
    }
    
    // Device information
    NSMutableAttributedString *deviceInformationString = [[NSMutableAttributedString alloc]
                                                          initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device"]
                                                          attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                       NSFontAttributeName: [UIFont boldSystemFontOfSize:15]}];
    [deviceInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
    
    if (mxDeviceInfo)
    {
        NSString *name = mxDeviceInfo.displayName;
        NSString *deviceId = mxDeviceInfo.deviceId;
        NSMutableAttributedString *verification;
        NSString *fingerprint = mxDeviceInfo.fingerprint;
        
        // Display here the Verify and Block buttons except if the device is the current one.
        _verifyButton.hidden = _blockButton.hidden = [mxDeviceInfo.deviceId isEqualToString:mxSession.matrixRestClient.credentials.deviceId];
        
        switch (mxDeviceInfo.verified)
        {
            case MXDeviceUnverified:
            {
                verification = [[NSMutableAttributedString alloc]
                                initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_not_verified"]
                                attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                             NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}];
                
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_verify"] forState:UIControlStateNormal];
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_verify"] forState:UIControlStateHighlighted];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_block"] forState:UIControlStateNormal];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_block"] forState:UIControlStateHighlighted];
                break;
            }
            case MXDeviceVerified:
            {
                verification = [[NSMutableAttributedString alloc]
                                initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_verified"]
                                attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                             NSFontAttributeName: [UIFont systemFontOfSize:14]}];
                
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_unverify"] forState:UIControlStateNormal];
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_unverify"] forState:UIControlStateHighlighted];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_block"] forState:UIControlStateNormal];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_block"] forState:UIControlStateHighlighted];
                
                break;
            }
            case MXDeviceBlocked:
            {
                verification = [[NSMutableAttributedString alloc]
                                initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_blocked"]
                                attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                             NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}];
                
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_verify"] forState:UIControlStateNormal];
                [_verifyButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_verify"] forState:UIControlStateHighlighted];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_unblock"] forState:UIControlStateNormal];
                [_blockButton setTitle:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_unblock"] forState:UIControlStateHighlighted];
                
                break;
            }
            default:
                break;
        }
        
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_name"]
                                                         attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                      NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:(name.length ? name : @"")
                                                         attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                      NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_id"]                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor, NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:deviceId
                                                         attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                      NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_verification"]                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor, NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:verification];
        [deviceInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
        
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_fingerprint"]                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor, NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:fingerprint
                                                         attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                      NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
        [deviceInformationString appendAttributedString:[MXKEncryptionInfoView verticalWhitespace]];
    }
    else
    {
        // Unknown device
        [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                         initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_info_device_unknown"]                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor, NSFontAttributeName: [UIFont italicSystemFontOfSize:14]}]];
    }
    
    [textViewAttributedString appendAttributedString:deviceInformationString];
    
    self.textView.attributedText = textViewAttributedString;
}

+ (NSAttributedString *)verticalWhitespace
{
    if (verticalWhitespace == nil)
    {
        verticalWhitespace = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:4]}];
    }
    return verticalWhitespace;
}

#pragma mark - Actions

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == _cancelButton)
    {
        [self removeFromSuperview];
    }
#ifdef MX_CRYPTO // Note: Verify and Block buttons are hidden when the deviceInfo is not available
    else if (sender == _confirmVerifyButton && mxDeviceInfo)
    {
        [mxSession.crypto setDeviceVerification:MXDeviceVerified forDevice:mxDeviceInfo.deviceId ofUser:mxDeviceInfo.userId success:nil failure:nil];
        [self removeFromSuperview];
    }
    else if (mxDeviceInfo)
    {
        MXDeviceVerification verificationStatus;
        
        if (sender == _verifyButton)
        {
            verificationStatus = ((mxDeviceInfo.verified == MXDeviceVerified) ? MXDeviceUnverified : MXDeviceVerified);
        }
        else if (sender == _blockButton)
        {
            verificationStatus = ((mxDeviceInfo.verified == MXDeviceBlocked) ? MXDeviceUnverified : MXDeviceBlocked);
        }
        else
        {
            // Unexpected case
            NSLog(@"[MXKEncryptionInfoView] Invalid button pressed.");
            return;
        }
        
        if (verificationStatus == MXDeviceVerified)
        {
            // Prompt user
            NSMutableAttributedString *textViewAttributedString = [[NSMutableAttributedString alloc]
                                                                   initWithString:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_verify_title"]                                                                   attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                                NSFontAttributeName: [UIFont boldSystemFontOfSize:17]}];
            
            NSString *message = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"room_event_encryption_verify_message"], mxDeviceInfo.displayName, mxDeviceInfo.deviceId, mxDeviceInfo.fingerprint];
            
            [textViewAttributedString appendAttributedString:[[NSMutableAttributedString alloc]
                                                             initWithString:message
                                                             attributes:@{NSForegroundColorAttributeName: _defaultTextColor,
                                                                          NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
            
            self.textView.attributedText = textViewAttributedString;
            
            [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
            [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] forState:UIControlStateHighlighted];
            _verifyButton.hidden = _blockButton.hidden = YES;
            _confirmVerifyButton.hidden = NO;
        }
        else
        {
            [mxSession.crypto setDeviceVerification:verificationStatus forDevice:mxDeviceInfo.deviceId ofUser:mxDeviceInfo.userId success:nil failure:nil];
            [self removeFromSuperview];
        }
    }
#endif
}

@end
