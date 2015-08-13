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

#import <UIKit/UIKit.h>

#import <MatrixSDK/MatrixSDK.h>

#import "MXKConstants.h"

#import "MXKAppSettings.h"

#import "MXEvent+MatrixKit.h"

#import "MXKTools.h"
#import "MXKAlert.h"
#import "MXKMediaManager.h"

#import "MXKViewController.h"
#import "MXKRoomViewController.h"
#import "MXKRecentListViewController.h"
#import "MXKRoomMemberListViewController.h"
#import "MXKCallViewController.h"
#import "MXKContactListViewController.h"
#import "MXKAccountDetailsViewController.h"
#import "MXKContactDetailsViewController.h"
#import "MXKRoomMemberDetailsViewController.h"
#import "MXKNotificationSettingsViewController.h"

#import "MXKAuthenticationViewController.h"

#import "MXKRoomCreationInputs.h"

#import "MXKInterleavedRecentsDataSource.h"

#import "MXKRoomCreationView.h"

#import "MXKRoomInputToolbarView.h"
#import "MXKRoomInputToolbarViewWithHPGrowingText.h"

#import "MXKRoomDataSourceManager.h"

#import "MXKRoomBubbleCellData.h"
#import "MXKRoomBubbleMergingMessagesCellData.h"

#import "MXKPublicRoomTableViewCell.h"

#import "MXKRoomMemberTableViewCell.h"
#import "MXKAccountTableViewCell.h"

#import "MXKPushRuleTableViewCell.h"
#import "MXKPushRuleCreationTableViewCell.h"

#import "MXKTableViewCellWithButton.h"
#import "MXKTableViewCellWithButtons.h"
#import "MXKTableViewCellWithLabelAndButton.h"
#import "MXKTableViewCellWithLabelAndSlider.h"
#import "MXKTableViewCellWithLabelAndSubLabel.h"
#import "MXKTableViewCellWithLabelAndSwitch.h"
#import "MXKTableViewCellWithLabelAndTextField.h"
#import "MXKTableViewCellWithLabelTextFieldAndButton.h"
#import "MXKTableViewCellWithPicker.h"
#import "MXKTableViewCellWithTextFieldAndButton.h"
#import "MXKTableViewCellWithTextView.h"

#import "MXKRoomTitleView.h"
#import "MXKRoomTitleViewWithTopic.h"

#import "MXKAccountManager.h"

#import "MXKContactManager.h"

#import "MXK3PID.h"
