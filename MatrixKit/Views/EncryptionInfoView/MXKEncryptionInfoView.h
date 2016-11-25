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

#import <MatrixSDK/MatrixSDK.h>

/**
 MXKEncryptionInfoView class may be used to display the available information on a encrypted event.
 The event sender device may be verified, unverified, blocked or unblocked from this view.
 */
@interface MXKEncryptionInfoView : UIView

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *verifyButton;
@property (weak, nonatomic) IBOutlet UIButton *blockButton;
@property (weak, nonatomic) IBOutlet UIButton *confirmVerifyButton;

- (instancetype)initWithEvent:(MXEvent*)event andMatrixSession:(MXSession*)session;

/**
 The default text color in the text view. [UIColor blackColor] by default.
 */
@property (nonatomic) UIColor *defaultTextColor;

@end

