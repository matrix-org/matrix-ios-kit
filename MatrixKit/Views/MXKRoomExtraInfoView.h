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

/**
 Customize UIView to display some extra info above the RoomInpuToolBar
 */
@interface MXKRoomExtraInfoView : UIView

/**
 Creates and returns a new `MXKRoomExtraInfoView-inherited` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKRoomExtraInfoView-inherited` object if successful, `nil` otherwise.
 */
+ (instancetype)roomExtraInfoView;

/**
 Dispose any resources and listener.
 */
- (void)destroy;

@end

