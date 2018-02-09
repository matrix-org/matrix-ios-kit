/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import "MXKRoomBubbleTableViewCell.h"

#import "MXKImageView.h"
#import "MXKPieChartView.h"
#import "MXKRoomBubbleCellData.h"
#import "MXKTools.h"

#import "NSBundle+MatrixKit.h"

#pragma mark - Constant definitions
NSString *const kMXKRoomBubbleCellTapOnMessageTextView = @"kMXKRoomBubbleCellTapOnMessageTextView";
NSString *const kMXKRoomBubbleCellTapOnSenderNameLabel = @"kMXKRoomBubbleCellTapOnSenderNameLabel";
NSString *const kMXKRoomBubbleCellTapOnAvatarView = @"kMXKRoomBubbleCellTapOnAvatarView";
NSString *const kMXKRoomBubbleCellTapOnDateTimeContainer = @"kMXKRoomBubbleCellTapOnDateTimeContainer";
NSString *const kMXKRoomBubbleCellTapOnAttachmentView = @"kMXKRoomBubbleCellTapOnAttachmentView";
NSString *const kMXKRoomBubbleCellTapOnOverlayContainer = @"kMXKRoomBubbleCellTapOnOverlayContainer";
NSString *const kMXKRoomBubbleCellTapOnContentView = @"kMXKRoomBubbleCellTapOnContentView";

NSString *const kMXKRoomBubbleCellUnsentButtonPressed = @"kMXKRoomBubbleCellUnsentButtonPressed";

NSString *const kMXKRoomBubbleCellLongPressOnEvent = @"kMXKRoomBubbleCellLongPressOnEvent";
NSString *const kMXKRoomBubbleCellLongPressOnProgressView = @"kMXKRoomBubbleCellLongPressOnProgressView";
NSString *const kMXKRoomBubbleCellLongPressOnAvatarView = @"kMXKRoomBubbleCellLongPressOnAvatarView";
NSString *const kMXKRoomBubbleCellShouldInteractWithURL = @"kMXKRoomBubbleCellShouldInteractWithURL";

NSString *const kMXKRoomBubbleCellUserIdKey = @"kMXKRoomBubbleCellUserIdKey";
NSString *const kMXKRoomBubbleCellEventKey = @"kMXKRoomBubbleCellEventKey";
NSString *const kMXKRoomBubbleCellReceiptsContainerKey = @"kMXKRoomBubbleCellReceiptsContainerKey";
NSString *const kMXKRoomBubbleCellUrl = @"kMXKRoomBubbleCellUrl";

static BOOL _disableLongPressGestureOnEvent;

@implementation MXKRoomBubbleTableViewCell
@synthesize delegate, bubbleData, readReceiptsAlignment;
@synthesize mxkCellData;

+ (instancetype)roomBubbleTableViewCell
{
    id instance = nil;
    
    // Check whether a xib is defined
    if ([[self class] nib])
    {
        @try {
            instance = [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
        }
        @catch (NSException *exception) {
        }
    }
    
    if (!instance)
    {
        instance = [[self alloc] init];
    }
    
    return instance;
}

+ (void)disableLongPressGestureOnEvent:(BOOL)disable
{
    _disableLongPressGestureOnEvent = disable;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    if (self.userNameLabel)
    {
        // Listen to name tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSenderNameTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        
        if (self.userNameTapGestureMaskView)
        {
            [self.userNameTapGestureMaskView addGestureRecognizer:tapGesture];
        }
        else
        {
            [self.userNameLabel addGestureRecognizer:tapGesture];
            self.userNameLabel.userInteractionEnabled = YES;
        }
    }
    
    if (self.pictureView)
    {
        self.pictureView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        
        // Listen to avatar tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAvatarTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.pictureView addGestureRecognizer:tapGesture];
        self.pictureView.userInteractionEnabled = YES;
        
        // Add a long gesture recognizer on avatar (in order to display for example the member details)
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
        [self.pictureView addGestureRecognizer:longPress];
    }
    
    if (self.messageTextView)
    {
        // Listen to textView tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMessageTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.messageTextView addGestureRecognizer:tapGesture];
        self.messageTextView.userInteractionEnabled = YES;

        // Recognise and make tappable phone numbers, address, etc.
        self.messageTextView.dataDetectorTypes = UIDataDetectorTypeAll;

        // Listen to link click
        self.messageTextView.delegate = self;
        
        if (_disableLongPressGestureOnEvent == NO)
        {
            // Add a long gesture recognizer on text view (in order to display for example the event details)
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.messageTextView addGestureRecognizer:longPress];
        }
    }
    
    if (self.playIconView)
    {
        self.playIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"play"];
    }
    
    if (self.bubbleOverlayContainer)
    {
        // Add tap recognizer on overlay container
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOverlayTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.bubbleOverlayContainer addGestureRecognizer:tapGesture];
    }
    
    // Listen to content view tap by default
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onContentViewTap:)];
    [tapGesture setNumberOfTouchesRequired:1];
    [tapGesture setNumberOfTapsRequired:1];
    [tapGesture setDelegate:self];
    [self.contentView addGestureRecognizer:tapGesture];
    
    self.readReceiptsAlignment = ReadReceiptAlignmentLeft;
}

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    // Clear the default background color of a MXKImageView instance
    self.pictureView.defaultBackgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.pictureView)
    {
        // Round image view
        [self.pictureView.layer setCornerRadius:self.pictureView.frame.size.width / 2];
        self.pictureView.clipsToBounds = YES;
    }
}

- (void)dealloc
{
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setAllTextHighlighted:(BOOL)allTextHighlighted
{
    if (self.messageTextView && bubbleData.textMessage.length != 0)
    {
        _allTextHighlighted = allTextHighlighted;
        
        if (allTextHighlighted)
        {
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
            UIColor *color = self.tintColor ? self.tintColor : [UIColor lightGrayColor];
            [highlightedString addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange(0, highlightedString.length)];
            self.messageTextView.attributedText = highlightedString;
        }
        else
        {
            self.messageTextView.attributedText = bubbleData.attributedTextMessage;
        }
    }
}

- (void)highlightTextMessageForEvent:(NSString*)eventId
{
    if (self.messageTextView)
    {
        if (eventId.length)
        {
            self.messageTextView.attributedText = [bubbleData attributedTextMessageWithHighlightedEvent:eventId tintColor:self.tintColor];
        }
        else
        {
            // Restore original string
            self.messageTextView.attributedText = bubbleData.attributedTextMessage;
        }
    }
}

- (CGFloat)topPositionOfEvent:(NSString*)eventId
{
    CGFloat topPositionOfEvent = 0;

    // Retrieve the component that hosts the event
    MXKRoomBubbleComponent *theComponent;
    for (MXKRoomBubbleComponent *component in bubbleData.bubbleComponents)
    {
        if ([component.event.eventId isEqualToString:eventId])
        {
            theComponent = component;
            break;
        }
    }

    if (theComponent)
    {
        topPositionOfEvent = theComponent.position.y + self.msgTextViewTopConstraint.constant;
    }
    return topPositionOfEvent;
}

- (CGFloat)bottomPositionOfEvent:(NSString*)eventId
{
    CGFloat bottomPositionOfEvent = self.frame.size.height - self.msgTextViewBottomConstraint.constant;
    
    // Parse each component by the end of the array in order to compute the bottom position.
    NSArray *bubbleComponents = bubbleData.bubbleComponents;
    NSInteger index = bubbleComponents.count;
    
    while (index --)
    {
        MXKRoomBubbleComponent *component = bubbleComponents[index];
        if ([component.event.eventId isEqualToString:eventId])
        {
            break;
        }
        else
        {
            // Update the bottom position
            bottomPositionOfEvent = component.position.y + self.msgTextViewTopConstraint.constant;
        }
    }
    return bottomPositionOfEvent;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)render:(MXKCellData *)cellData
{
    [self originalRender:cellData];
}

- (void)originalRender:(MXKCellData *)cellData
{
    // Sanity check: accept only object of MXKRoomBubbleCellData classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKRoomBubbleCellData class]]);
    
    bubbleData = (MXKRoomBubbleCellData*)cellData;
    mxkCellData = cellData;
    
    if (bubbleData)
    {
        // Check conditions to display the message sender name
        if (self.userNameLabel)
        {
            // Display sender's name except if the name appears in the displayed text (see emote and membership events)
            if (bubbleData.shouldHideSenderName == NO)
            {
                if (bubbleData.senderFlair)
                {
                    [self renderSenderFlair];
                }
                else
                {
                    self.userNameLabel.text = bubbleData.senderDisplayName;
                }
                
                
                self.userNameLabel.hidden = NO;
                self.userNameTapGestureMaskView.userInteractionEnabled = YES;
            }
            else
            {
                self.userNameLabel.hidden = YES;
                self.userNameTapGestureMaskView.userInteractionEnabled = NO;
            }
        }
        
        // Check whether the sender's picture is actually displayed before loading it.
        if (self.pictureView)
        {
            // Handle user's picture
            NSString *avatarThumbURL = nil;
            if (bubbleData.senderAvatarUrl)
            {
                // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
                avatarThumbURL = [bubbleData.mxSession.matrixRestClient urlOfContentThumbnail:bubbleData.senderAvatarUrl toFitViewSize:self.pictureView.frame.size withMethod:MXThumbnailingMethodCrop];
            }
            self.pictureView.enableInMemoryCache = YES;
            [self.pictureView setImageURL:avatarThumbURL withType:nil andImageOrientation:UIImageOrientationUp previewImage: bubbleData.senderAvatarPlaceholder ? bubbleData.senderAvatarPlaceholder : self.picturePlaceholder];
        }
        
        if (self.attachmentView && bubbleData.isAttachmentWithThumbnail)
        {
            // Set attached media folders
            self.attachmentView.mediaFolder = bubbleData.roomId;
            
            self.attachmentView.backgroundColor = [UIColor clearColor];
            
            // Retrieve the suitable content size for the attachment thumbnail
            CGSize contentSize = bubbleData.contentSize;
            
            // Update image view frame in order to center loading wheel (if any)
            CGRect frame = self.attachmentView.frame;
            frame.size.width = contentSize.width;
            frame.size.height = contentSize.height;
            self.attachmentView.frame = frame;
            
            NSString *mimetype = nil;
            if (bubbleData.attachment.thumbnailInfo)
            {
                mimetype = bubbleData.attachment.thumbnailInfo[@"mimetype"];
            }
            else if (bubbleData.attachment.contentInfo)
            {
                mimetype = bubbleData.attachment.contentInfo[@"mimetype"];
            }
            
            if (bubbleData.attachment.type == MXKAttachmentTypeVideo)
            {
                self.playIconView.hidden = NO;
                self.fileTypeIconView.hidden = YES;
            }
            else
            {
                self.playIconView.hidden = YES;
                if ([mimetype isEqualToString:@"image/gif"])
                {
                    self.fileTypeIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"filetype-gif"];
                    self.fileTypeIconView.hidden = NO;
                }
                else
                {
                    self.fileTypeIconView.hidden = YES;
                }
            }
            
            self.attachmentView.enableInMemoryCache = YES;
            [self.attachmentView setAttachmentThumb:bubbleData.attachment];
            
            if (bubbleData.attachment.actualURL)
            {
                // Add tap recognizer to open attachment
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAttachmentTap:)];
                [tap setNumberOfTouchesRequired:1];
                [tap setNumberOfTapsRequired:1];
                [tap setDelegate:self];
                [self.attachmentView addGestureRecognizer:tap];
            }
            
            [self startProgressUI];
            
            // Adjust Attachment width constant
            self.attachViewWidthConstraint.constant = contentSize.width;
            
            // Add a long gesture recognizer on progressView to cancel the current operation (Note: only the download can be cancelled).
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.progressView addGestureRecognizer:longPress];
            
            if (_disableLongPressGestureOnEvent == NO)
            {
                // Add a long gesture recognizer on attachment view in order to display for example the event details
                longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
                [self.attachmentView addGestureRecognizer:longPress];
            }
        }
        else if (self.messageTextView)
        {
            // Compute message content size
            bubbleData.maxTextViewWidth = self.frame.size.width - (self.msgTextViewLeadingConstraint.constant + self.msgTextViewTrailingConstraint.constant);
            CGSize contentSize = bubbleData.contentSize;
            
            // Prepare displayed text message
            NSAttributedString* newText = nil;
            
            // Underline attached file name
            if (bubbleData.attachment && (bubbleData.attachment.type == MXKAttachmentTypeFile || bubbleData.attachment.type == MXKAttachmentTypeAudio) && bubbleData.attachment.actualURL && bubbleData.attachment.contentInfo)
            {
                NSMutableAttributedString *updatedText = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
                [updatedText addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, updatedText.length)];
                
                newText = updatedText;
            }
            else
            {
                newText = bubbleData.attributedTextMessage;
            }
            
            // update the text only if it is required
            // updating a text is quite long (even with the same text).
            if (![self.messageTextView.attributedText isEqualToAttributedString:newText])
            {
                self.messageTextView.attributedText = newText;
            }
            
            // Update msgTextView width constraint to align correctly the text
            if (self.msgTextViewWidthConstraint.constant != contentSize.width)
            {
                self.msgTextViewWidthConstraint.constant = contentSize.width;
            }
        }
        
        // Check and update each component position (used to align timestamps label in front of events, and to handle tap gesture on events)
        [bubbleData prepareBubbleComponentsPosition];
        
        // Handle here timestamp display (only if a container has been defined)
        if (self.bubbleInfoContainer)
        {
            if ((bubbleData.showBubbleDateTime && !bubbleData.useCustomDateTimeLabel)
                || (bubbleData.showBubbleReceipts && !bubbleData.useCustomReceipts))
            {
                // Add datetime label for each component
                self.bubbleInfoContainer.hidden = NO;
                
                // ensure that older subviews are removed
                // They should be (they are removed when the is not anymore used).
                // But, it seems that is not always true.
                NSArray* views = [self.bubbleInfoContainer subviews];
                for(UIView* view in views)
                {
                    [view removeFromSuperview];
                }
                
                for (MXKRoomBubbleComponent *component in bubbleData.bubbleComponents)
                {
                    if (component.event.sentState != MXEventSentStateFailed)
                    {
                        CGFloat timeLabelOffset = 0;
                        
                        if (component.date && bubbleData.showBubbleDateTime && !bubbleData.useCustomDateTimeLabel)
                        {
                            UILabel *dateTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, component.position.y, self.bubbleInfoContainer.frame.size.width , 15)];
                            
                            dateTimeLabel.text = [bubbleData.eventFormatter dateStringFromDate:component.date withTime:YES];
                            if (bubbleData.isIncoming)
                            {
                                dateTimeLabel.textAlignment = NSTextAlignmentRight;
                            }
                            else
                            {
                                dateTimeLabel.textAlignment = NSTextAlignmentLeft;
                            }
                            dateTimeLabel.textColor = [UIColor lightGrayColor];
                            dateTimeLabel.font = [UIFont systemFontOfSize:11];
                            dateTimeLabel.adjustsFontSizeToFitWidth = YES;
                            dateTimeLabel.minimumScaleFactor = 0.6;
                            
                            [dateTimeLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
                            [self.bubbleInfoContainer addSubview:dateTimeLabel];
                            // Force dateTimeLabel in full width (to handle auto-layout in case of screen rotation)
                            NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                              attribute:NSLayoutAttributeLeading
                                                                                              relatedBy:NSLayoutRelationEqual
                                                                                                 toItem:self.bubbleInfoContainer
                                                                                              attribute:NSLayoutAttributeLeading
                                                                                             multiplier:1.0
                                                                                               constant:0];
                            NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                               attribute:NSLayoutAttributeTrailing
                                                                                               relatedBy:NSLayoutRelationEqual
                                                                                                  toItem:self.bubbleInfoContainer
                                                                                               attribute:NSLayoutAttributeTrailing
                                                                                              multiplier:1.0
                                                                                                constant:0];
                            // Vertical constraints are required for iOS > 8
                            NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                             attribute:NSLayoutAttributeTop
                                                                                             relatedBy:NSLayoutRelationEqual
                                                                                                toItem:self.bubbleInfoContainer
                                                                                             attribute:NSLayoutAttributeTop
                                                                                            multiplier:1.0
                                                                                              constant:component.position.y];
                            NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                                attribute:NSLayoutAttributeHeight
                                                                                                relatedBy:NSLayoutRelationEqual
                                                                                                   toItem:nil
                                                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                                                               multiplier:1.0
                                                                                                 constant:15];
                            if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
                            {
                                [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, heightConstraint]];
                            }
                            else
                            {
                                [self.bubbleInfoContainer addConstraint:leftConstraint];
                                [self.bubbleInfoContainer addConstraint:rightConstraint];
                                [self.bubbleInfoContainer addConstraint:topConstraint];
                                [dateTimeLabel addConstraint:heightConstraint];
                            }
                            
                            timeLabelOffset += 15;
                        }
                        
                        if (bubbleData.showBubbleReceipts && !bubbleData.useCustomReceipts)
                        {
                            NSMutableArray* roomMembers = nil;
                            NSMutableArray* placeholders = nil;
                            NSArray* receipts = nil;
                            
                            MXRoom* room = [bubbleData.mxSession roomWithRoomId:bubbleData.roomId];
                            
                            // Get the events receipts by ignoring the current user receipt.
                            if (room)
                            {
                                receipts = [room getEventReceipts:component.event.eventId sorted:YES];
                            }
                            
                            // Check whether some receipts are found
                            if (receipts.count)
                            {
                                // Retrieve the corresponding room members
                                roomMembers = [[NSMutableArray alloc] initWithCapacity:receipts.count];
                                placeholders = [[NSMutableArray alloc] initWithCapacity:receipts.count];
                                
                                for (MXReceiptData* data in receipts)
                                {
                                    MXRoomMember * roomMember = [room.state memberWithUserId:data.userId];
                                    if (roomMember)
                                    {
                                        [roomMembers addObject:roomMember];
                                        [placeholders addObject:self.picturePlaceholder];
                                    }
                                }
                            }
                            
                            if (roomMembers.count)
                            {
                                MXKReceiptSendersContainer* avatarsContainer = [[MXKReceiptSendersContainer alloc] initWithFrame:CGRectMake(0, component.position.y + timeLabelOffset, self.bubbleInfoContainer.frame.size.width , 15) andRestClient:bubbleData.mxSession.matrixRestClient];
                                
                                [avatarsContainer refreshReceiptSenders:roomMembers withPlaceHolders:placeholders andAlignment:self.readReceiptsAlignment];
                                
                                [self.bubbleInfoContainer addSubview:avatarsContainer];
                                
                                // Force dateTimeLabel in full width (to handle auto-layout in case of screen rotation)
                                NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                  attribute:NSLayoutAttributeLeading
                                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                                     toItem:self.bubbleInfoContainer
                                                                                                  attribute:NSLayoutAttributeLeading
                                                                                                 multiplier:1.0
                                                                                                   constant:0];
                                NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                   attribute:NSLayoutAttributeTrailing
                                                                                                   relatedBy:NSLayoutRelationEqual
                                                                                                      toItem:self.bubbleInfoContainer
                                                                                                   attribute:NSLayoutAttributeTrailing
                                                                                                  multiplier:1.0
                                                                                                    constant:0];
                                // Vertical constraints are required for iOS > 8
                                NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                 attribute:NSLayoutAttributeTop
                                                                                                 relatedBy:NSLayoutRelationEqual
                                                                                                    toItem:self.bubbleInfoContainer
                                                                                                 attribute:NSLayoutAttributeTop
                                                                                                multiplier:1.0
                                                                                                  constant:(component.position.y + timeLabelOffset)];
                                
                                NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                    attribute:NSLayoutAttributeHeight
                                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                                       toItem:nil
                                                                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                                                                   multiplier:1.0
                                                                                                     constant:15];
                                
                                if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
                                {
                                    [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, heightConstraint]];
                                }
                                else
                                {
                                    [self.bubbleInfoContainer addConstraint:leftConstraint];
                                    [self.bubbleInfoContainer addConstraint:rightConstraint];
                                    [self.bubbleInfoContainer addConstraint:topConstraint];
                                    [avatarsContainer addConstraint:heightConstraint];
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                self.bubbleInfoContainer.hidden = YES;
            }
        }
    }
}

- (void)renderSenderFlair
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  ", bubbleData.senderDisplayName]];
    
    NSUInteger index = 0;
    NSString *mimeType;
    
    for (MXGroup *group in bubbleData.senderFlair)
    {
        // Compute the group avatar URL
        NSString *avatarUrl = group.profile.avatarUrl;
        
        if (avatarUrl.length)
        {
            avatarUrl = [bubbleData.mxSession.matrixRestClient urlOfContentThumbnail:avatarUrl toFitViewSize:CGSizeMake(12, 12) withMethod:MXThumbnailingMethodCrop];
            
            // Check if the extension could not be deduced from url
            if (![avatarUrl pathExtension].length)
            {
                // Set default mime type if no information is available
                mimeType = @"image/jpeg";
            }
            else
            {
                mimeType = nil;
            }
            
            NSString *cacheFilePath = [MXMediaManager cachePathForMediaWithURL:avatarUrl andType:mimeType inFolder:kMXMediaManagerDefaultCacheFolder];
            UIImage *image = [MXMediaManager loadThroughCacheWithFilePath:cacheFilePath];
            if (image)
            {
                NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
                textAttachment.image = [MXKTools resizeImageWithRoundedCorners:image toSize:CGSizeMake(12, 12)];
                NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
                [attributedString appendAttributedString:attrStringWithImage];
                [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
            }
            else
            {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXMediaDownloadDidFinishNotification object:avatarUrl];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXMediaDownloadDidFailNotification object:avatarUrl];
                
                MXMediaLoader* loader = [MXMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
                if (!loader)
                {
                    [MXMediaManager downloadMediaFromURL:avatarUrl andSaveAtFilePath:cacheFilePath];
                }
            }
            
            index++;
            if (index == 3)
            {
                if (bubbleData.senderFlair.count > 3)
                {
                    NSAttributedString *more = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"+%tu", (bubbleData.senderFlair.count - 3)] attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11.0], NSBaselineOffsetAttributeName:@(+2)}];
                    [attributedString appendAttributedString:more];
                }
                break;
            }
        }
    }
    
    self.userNameLabel.attributedText = attributedString;
}

+ (CGFloat)heightForCellData:(MXKCellData*)cellData withMaximumWidth:(CGFloat)maxWidth
{
    return [self originalHeightForCellData:cellData withMaximumWidth:maxWidth];
}

+ (CGFloat)originalHeightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // Sanity check: accept only object of MXKRoomBubbleCellData classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKRoomBubbleCellData class]]);
    
    MXKRoomBubbleCellData *bubbleData = (MXKRoomBubbleCellData*)cellData;
    MXKRoomBubbleTableViewCell* cell = [self cellWithOriginalXib];
    CGFloat rowHeight = cell.frame.size.height;
    
    if (cell.attachmentView && bubbleData.isAttachmentWithThumbnail)
    {
        // retrieve the suggested image view height
        rowHeight = bubbleData.contentSize.height;
        
        // Check here the minimum height defined in cell view for text message
        if (cell.attachViewMinHeightConstraint && rowHeight < cell.attachViewMinHeightConstraint.constant)
        {
            rowHeight = cell.attachViewMinHeightConstraint.constant;
        }
        
        // Finalize the row height by adding the vertical constraints.
        rowHeight += cell.attachViewTopConstraint.constant + cell.attachViewBottomConstraint.constant;
    }
    else if (cell.messageTextView)
    {
        // Update maximum width available for the textview
        bubbleData.maxTextViewWidth = maxWidth - (cell.msgTextViewLeadingConstraint.constant + cell.msgTextViewTrailingConstraint.constant);
        
        // Retrieve the suggested height of the message content
        rowHeight = bubbleData.contentSize.height;
        
        // Consider here the minimum height defined in cell view for text message
        if (cell.msgTextViewMinHeightConstraint && rowHeight < cell.msgTextViewMinHeightConstraint.constant)
        {
            rowHeight = cell.msgTextViewMinHeightConstraint.constant;
        }
        
        // Finalize the row height by adding the top and bottom constraints of the message text view in cell
        rowHeight += cell.msgTextViewTopConstraint.constant + cell.msgTextViewBottomConstraint.constant;
    }
    
    return rowHeight;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self didEndDisplay];
}

- (void)didEndDisplay
{
    bubbleData = nil;
    
    if (_readMarkerView)
    {
        [_readMarkerView removeFromSuperview];
        _readMarkerView = nil;
        _readMarkerViewTopConstraint = nil;
        _readMarkerViewLeadingConstraint = nil;
        _readMarkerViewTrailingConstraint = nil;
        _readMarkerViewHeightConstraint = nil;
    }
    
    if (self.attachmentView)
    {
        // Remove all gesture recognizer
        while (self.attachmentView.gestureRecognizers.count)
        {
            [self.attachmentView removeGestureRecognizer:self.attachmentView.gestureRecognizers[0]];
        }
        
        // Prevent the cell from displaying again the image in case of reuse.
        self.attachmentView.image = nil;
    }
    
    // Remove potential dateTime (or unsent) label(s)
    if (self.bubbleInfoContainer && self.bubbleInfoContainer.subviews.count > 0)
    {
        NSArray* subviews = self.bubbleInfoContainer.subviews;
             
        for (UIView *view in subviews)
        {
            [view removeFromSuperview];
        }
    }
    self.bubbleInfoContainer.hidden = YES;
    
    // Remove temporary subviews
    if (self.tmpSubviews)
    {
        for (UIView *view in self.tmpSubviews)
        {
            [view removeFromSuperview];
        }
        self.tmpSubviews = nil;
    }
    
    // Remove potential overlay subviews
    if (self.bubbleOverlayContainer)
    {
        NSArray* subviews = self.bubbleOverlayContainer.subviews;
        
        for (UIView *view in subviews)
        {
            [view removeFromSuperview];
        }
        
        self.bubbleOverlayContainer.hidden = YES;
    }
    
    if (self.progressView)
    {
        [self stopProgressUI];
        
        // Remove long tap gesture on the progressView
        while (self.progressView.gestureRecognizers.count)
        {
            [self.progressView removeGestureRecognizer:self.progressView.gestureRecognizers[0]];
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
}

#pragma mark - Attachment progress handling

- (void)updateProgressUI:(NSDictionary*)statisticsDict
{
    self.progressView.hidden = !statisticsDict;
    
    NSNumber* downloadRate = [statisticsDict valueForKey:kMXMediaLoaderCurrentDataRateKey];
    
    NSNumber* completedBytesCount = [statisticsDict valueForKey:kMXMediaLoaderCompletedBytesCountKey];
    NSNumber* totalBytesCount = [statisticsDict valueForKey:kMXMediaLoaderTotalBytesCountKey];
    
    NSMutableString* text = [[NSMutableString alloc] init];
    
    if (completedBytesCount && totalBytesCount)
    {
        NSString* progressString = [NSString stringWithFormat:@"%@ / %@", [NSByteCountFormatter stringFromByteCount:completedBytesCount.longLongValue countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalBytesCount.longLongValue countStyle:NSByteCountFormatterCountStyleFile]];
        
        [text appendString:progressString];
    }
    
    if (downloadRate && downloadRate.longLongValue)
    {
        [text appendFormat:@"\n%@/s", [NSByteCountFormatter stringFromByteCount:downloadRate.longLongValue countStyle:NSByteCountFormatterCountStyleFile]];
        
        if (completedBytesCount && totalBytesCount)
        {
            CGFloat remainimgTime = ((totalBytesCount.floatValue - completedBytesCount.floatValue)) / downloadRate.floatValue;
            [text appendFormat:@"\n%@", [MXKTools formatSecondsInterval:remainimgTime]];
        }
    }
    
    self.statsLabel.text = text;
    
    NSNumber* progressNumber = [statisticsDict valueForKey:kMXMediaLoaderProgressValueKey];
    
    if (progressNumber)
    {
        self.progressChartView.progress = progressNumber.floatValue;
    }
}

- (void)onMediaDownloadProgress:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* url = notif.object;
        
        if ([url isEqualToString:bubbleData.attachment.actualURL])
        {
            [self updateProgressUI:notif.userInfo];
        }
    }
}

- (void)onMediaDownloadEnd:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* url = notif.object;
        
        if ([url isEqualToString:bubbleData.attachment.actualURL])
        {
            [self stopProgressUI];
        }
        else
        {
            // Refresh sender flair
            [self renderSenderFlair];
        }
        
        // remove any pending observers
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadDidFinishNotification object:url];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadDidFailNotification object:url];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadProgressNotification object:url];
    }
}

- (void)startProgressUI
{
    BOOL isHidden = YES;
    
    // there is an attachment URL
    if (bubbleData.attachment.actualURL)
    {
        NSString* url = bubbleData.attachment.actualURL;
        
        // remove any pending observers
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadDidFinishNotification object:url];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadDidFailNotification object:url];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadProgressNotification object:url];
        
        // check if there is a download in progress
        MXMediaLoader *loader = [MXMediaManager existingDownloaderWithOutputFilePath:bubbleData.attachment.cacheFilePath];
        if (loader)
        {
            NSDictionary *dict = loader.statisticsDict;
            if (dict)
            {
                isHidden = NO;
                
                // defines the text to display
                [self updateProgressUI:dict];
            }
            
            // anyway listen to the progress event
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXMediaDownloadDidFinishNotification object:url];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXMediaDownloadDidFailNotification object:url];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadProgress:) name:kMXMediaDownloadProgressNotification object:url];
        }
    }
    
    self.progressView.hidden = isHidden;
}

- (void)stopProgressUI
{
    self.progressView.hidden = YES;
    
    // do not remove the observer here
    // the download could restart without recomposing the cell
}

#pragma mark - Original Xib values

/**
 `childClasses` hosts one instance of each child classes of `MXKRoomBubbleTableViewCell`.
 The key is the child class name. The value, the instance.
 */
static NSMutableDictionary *childClasses;

+ (MXKRoomBubbleTableViewCell*)cellWithOriginalXib
{
    MXKRoomBubbleTableViewCell *cellWithOriginalXib;
    
    @synchronized(self)
    {
        if (childClasses == nil)
        {
            childClasses = [NSMutableDictionary dictionary];
        }
        
        // To save memory, use only one original instance per child class
        cellWithOriginalXib = childClasses[NSStringFromClass(self.class)];
        if (nil == cellWithOriginalXib)
        {
            cellWithOriginalXib = [self roomBubbleTableViewCell];
            
            childClasses[NSStringFromClass(self.class)] = cellWithOriginalXib;
        }
    }
    return cellWithOriginalXib;
}

#pragma mark - User actions

- (IBAction)onMessageTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        // Check whether the current displayed text corresponds to an attached file
        if (bubbleData.attachment && (bubbleData.attachment.type == MXKAttachmentTypeFile || bubbleData.attachment.type == MXKAttachmentTypeAudio) && bubbleData.attachment.actualURL && bubbleData.attachment.contentInfo)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAttachmentView userInfo:nil];
        }
        else
        {
            MXEvent *tappedEvent = nil;
            NSArray *bubbleComponents = bubbleData.bubbleComponents;
            if (bubbleComponents.count == 1)
            {
                MXKRoomBubbleComponent *component = [bubbleComponents firstObject];
                tappedEvent = component.event;
            }
            else if (bubbleComponents.count)
            {
                // Look for the tapped component
                UIView* view = sender.view;
                CGPoint tapPoint = [sender locationInView:view];
                
                for (MXKRoomBubbleComponent *component in bubbleComponents)
                {
                    // Ignore components without display.
                    if (!component.attributedTextMessage)
                    {
                        continue;
                    }
                        
                    if (tapPoint.y < component.position.y)
                    {
                        break;
                    }
                    tappedEvent = component.event;
                }
            }
            
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnMessageTextView userInfo:(tappedEvent ? @{kMXKRoomBubbleCellEventKey:tappedEvent} : nil)];
        }
    }
}

- (IBAction)onSenderNameTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnSenderNameLabel userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
    }
}

- (IBAction)onAvatarTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAvatarView userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
    }
}

- (IBAction)onAttachmentTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAttachmentView userInfo:nil];
    }
}

- (IBAction)showHideDateTime:(id)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnDateTimeContainer userInfo:nil];
    }
}

- (IBAction)onOverlayTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnOverlayContainer userInfo:nil];
    }
}

- (IBAction)onContentViewTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        // Check whether a bubble component is displayed at the level of the tapped line.
        MXKRoomBubbleComponent *tappedComponent = nil;
        NSArray *bubbleComponents = bubbleData.bubbleComponents;
        
        CGPoint tapPoint;
        if (self.attachmentView)
        {
            // Check whether the user tapped on the side of the attachment.
            tapPoint = [sender locationInView:self.attachmentView];
            
            if (tapPoint.y > 0 && tapPoint.y < self.attachmentView.frame.size.height)
            {
                // Only one component is available in bubble with attachment.
                tappedComponent = [bubbleComponents firstObject];
            }
        }
        else if (self.messageTextView)
        {
            // Check whether the user tapped in front of a text component.
            tapPoint = [sender locationInView:self.messageTextView];
            
            if (tapPoint.y > 0 && tapPoint.y < self.messageTextView.frame.size.height)
            {
                // Consider by default the first component
                tappedComponent = [bubbleComponents firstObject];
                
                for (NSInteger index = 1; index < bubbleComponents.count; index++)
                {
                    // Here the bubble is composed by multiple text messages
                    MXKRoomBubbleComponent *component = bubbleComponents[index];
                    if (tapPoint.y < component.position.y)
                    {
                        break;
                    }
                    tappedComponent = component;
                }
            }
        }
        
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnContentView userInfo:(tappedComponent ? @{kMXKRoomBubbleCellEventKey:tappedComponent.event} : nil)];
    }
}

- (IBAction)onLongPressGesture:(UILongPressGestureRecognizer*)longPressGestureRecognizer
{
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan && delegate)
    {
        UIView* view = longPressGestureRecognizer.view;
        
        NSArray *bubbleComponents = bubbleData.bubbleComponents;
        
        // Check the view on which long press has been detected
        if (view == self.progressView)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnProgressView userInfo:nil];
        }
        else if (view == self.messageTextView || view == self.attachmentView)
        {
            MXEvent *selectedEvent = nil;
            if (bubbleComponents.count == 1)
            {
                MXKRoomBubbleComponent *component = [bubbleComponents firstObject];
                selectedEvent = component.event;
            }
            else if (bubbleComponents.count)
            {
                // Here the selected view is a textView (attachment has no more than one component)
                
                // Look for the selected component
                CGPoint longPressPoint = [longPressGestureRecognizer locationInView:view];
                for (MXKRoomBubbleComponent *component in bubbleComponents)
                {
                    // Ignore components without display.
                    if (!component.attributedTextMessage)
                    {
                        continue;
                    }
                    
                    if (longPressPoint.y < component.position.y)
                    {
                        break;
                    }
                    selectedEvent = component.event;
                }
            }
            
            if (selectedEvent)
            {
                [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnEvent userInfo:@{kMXKRoomBubbleCellEventKey:selectedEvent}];
            }
        }
        else if (view == self.pictureView)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnAvatarView userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
        }
    }
}

#pragma mark - UITextView delegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    BOOL shouldInteractWithURL = YES;
    if (delegate && URL)
    {
        // Ask the delegate if iOS can open the link
        shouldInteractWithURL = [delegate cell:self shouldDoAction:kMXKRoomBubbleCellShouldInteractWithURL userInfo:@{kMXKRoomBubbleCellUrl:URL} defaultValue:YES];
    }
    return shouldInteractWithURL;
}

@end
