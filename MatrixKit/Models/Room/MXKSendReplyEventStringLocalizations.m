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


#import "MXKSendReplyEventStringLocalizations.h"

#import "NSBundle+MatrixKit.h"

@implementation MXKSendReplyEventStringLocalizations

- (instancetype)init
{
    self = [super init];
    if (self) {
        _senderSentAnImage = [NSBundle mxk_localizedStringForKey:@"message_reply_to_sender_sent_an_image"];
        _senderSentAVideo = [NSBundle mxk_localizedStringForKey:@"message_reply_to_sender_sent_a_video"];
        _senderSentAnAudioFile = [NSBundle mxk_localizedStringForKey:@"message_reply_to_sender_sent_an_audio_file"];
        _senderSentAVoiceMessage = [NSBundle mxk_localizedStringForKey:@"message_reply_to_sender_sent_a_voice_message"];
        _senderSentAFile = [NSBundle mxk_localizedStringForKey:@"message_reply_to_sender_sent_a_file"];
        _messageToReplyToPrefix = [NSBundle mxk_localizedStringForKey:@"message_reply_to_message_to_reply_to_prefix"];                
    }
    return self;
}

@end
