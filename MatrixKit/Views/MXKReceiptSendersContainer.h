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

typedef NS_ENUM(NSInteger, ReadReceiptsAlignment)
{
    /**
     The latest receipt is displayed on left
     */
    ReadReceiptAlignmentLeft = 0,
    
    /**
     The latest receipt is displayed on right
     */
    ReadReceiptAlignmentRight = 1,
};

/*
 Protocol to provide interface for actions related to the MXKReceiptSendersContainer view
 */
@protocol MXKRecieptSendersContainerDelegate <NSObject>

@optional

- (void)didTapReceiptsContainerWithRestClient:(MXRestClient *)restClient RoomMembers:(NSArray *)roomMembers avatars:(NSArray *)avatars recieptDescriptions:(NSArray *)recieptDescriptions;

@end

/**
 `MXKReceiptSendersContainer` is a view dedicated to display receipt senders by using their avatars.
 
 This container handles automatically the number of visible avatars. A label is added when avatars are not all visible (see 'moreLabel' property).
 */
@interface MXKReceiptSendersContainer : UIView

/**
 The REST client used to resize matrix user's avatar.
 */
@property (nonatomic) MXRestClient* restClient;

/**
 The maximum number of avatars displayed in the container. 3 by default.
 */
@property (nonatomic) NSInteger maxDisplayedAvatars;

/**
 The space between avatars. 2.0 points by default.
 */
@property (nonatomic) CGFloat avatarMargin;

/**
 The label added beside avatars when avatars are not all visible.
 */
@property (nonatomic) UILabel* moreLabel;

/**
 The receipt descriptions to show in the details view controller.
 */
@property (nonatomic) NSArray <NSString *> *recieptDescriptions;

/*
 The delegate of the ReadReceiptsContainer
 */
@property (nonatomic, weak) id<MXKRecieptSendersContainerDelegate> delegate;

/**
 Initializes an `MXKReceiptSendersContainer` object with a frame and a REST client.
 
 This is the designated initializer.
 
 @param frame the container frame. Note that avatar will be displayed in full height in this container.
 @param restclient the REST client used to resize matrix user's avatar.
 @return The newly-initialized MXKReceiptSendersContainer instance
 */
- (instancetype)initWithFrame:(CGRect)frame andRestClient:(MXRestClient*)restclient;

/**
 Refresh the container content by using the provided room members.
 
 @param roomMembers list of room members sorted from the latest receipt to the oldest receipt.
 @param placeHolders list of placeholders, one by room member. Used when url is nil, or during avatar download.
 @param alignment (see ReadReceiptsAlignment).
 */
- (void)refreshReceiptSenders:(NSArray<MXRoomMember*>*)roomMembers withPlaceHolders:(NSArray<UIImage*>*)placeHolders andAlignment:(ReadReceiptsAlignment)alignment;

@end

