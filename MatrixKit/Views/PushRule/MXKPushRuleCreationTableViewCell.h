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

#import <MatrixSDK/MatrixSDK.h>

#import "MXKTableViewCell.h"

/**
 MXPushRuleCreationTableViewCell instance is a table view cell used to create a new push rule.
 */
@interface MXKPushRuleCreationTableViewCell : MXKTableViewCell <UIPickerViewDataSource, UIPickerViewDelegate>

/**
 The category the created push rule will belongs to
 */
@property (nonatomic) MXPushRuleKind mxPushRuleKind;

/**
 The related matrix session
 */
@property (nonatomic) MXSession* mxSession;

/**
 The graphics items
 */
@property (strong, nonatomic) IBOutlet UITextField* inputTextField;
@property (strong, nonatomic) IBOutlet UIPickerView* roomPicker;

@property (strong, nonatomic) IBOutlet UIButton* addButton;

@end
