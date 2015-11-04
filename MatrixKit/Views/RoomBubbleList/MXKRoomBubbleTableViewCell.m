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

#import "MXKRoomBubbleTableViewCell.h"

#import "NSBundle+MatrixKit.h"

#import "MXKReceiptAvartarsContainer.h"
#import "MXRoom.h"

#pragma mark - Constant definitions
NSString *const kMXKRoomBubbleCellTapOnMessageTextView = @"kMXKRoomBubbleCellTapOnMessageTextView";
NSString *const kMXKRoomBubbleCellTapOnAvatarView = @"kMXKRoomBubbleCellTapOnAvatarView";
NSString *const kMXKRoomBubbleCellTapOnDateTimeContainer = @"kMXKRoomBubbleCellTapOnDateTimeContainer";
NSString *const kMXKRoomBubbleCellTapOnAttachmentView = @"kMXKRoomBubbleCellTapOnAttachmentView";
NSString *const kMXKRoomBubbleCellUnsentButtonPressed = @"kMXKRoomBubbleCellUnsentButtonPressed";

NSString *const kMXKRoomBubbleCellLongPressOnEvent = @"kMXKRoomBubbleCellLongPressOnEvent";
NSString *const kMXKRoomBubbleCellLongPressOnProgressView = @"kMXKRoomBubbleCellLongPressOnProgressView";

NSString *const kMXKRoomBubbleCellUserIdKey = @"kMXKRoomBubbleCellUserIdKey";
NSString *const kMXKRoomBubbleCellEventKey = @"kMXKRoomBubbleCellEventKey";


@implementation MXKRoomBubbleTableViewCell
@synthesize delegate, bubbleData;

+ (instancetype)roomBubbleTableViewCell
{
    // Check whether a xib is defined
    if ([[self class] nib])
    {
        return [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
    }
    
    return [[[self class] alloc] init];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.pictureView.backgroundColor = [UIColor clearColor];
    
    self.playIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"play"];
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
    if (bubbleData.textMessage.length != 0)
    {
        _allTextHighlighted = allTextHighlighted;
        
        if (allTextHighlighted)
        {
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
            UIColor *color = self.tintColor ? self.tintColor : [UIColor lightGrayColor];
            [highlightedString addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange(0, highlightedString.length)];
            _messageTextView.attributedText = highlightedString;
        }
        else
        {
            _messageTextView.attributedText = bubbleData.attributedTextMessage;
        }
    }
}

- (void)highlightTextMessageForEvent:(NSString*)eventId
{
    if (bubbleData.attachment == nil)
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
    if (bubbleData)
    {
        MXKRoomBubbleTableViewCell* cellWithOriginalXib = self.class.cellWithOriginalXib;
        
        // set the media folders
        self.pictureView.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
        self.attachmentView.mediaFolder = bubbleData.roomId;
        
        // Handle sender's picture and adjust view's constraints
        self.pictureView.hidden = NO;
        self.msgTextViewTopConstraint.constant = cellWithOriginalXib.msgTextViewTopConstraint.constant;
        self.attachViewTopConstraint.constant = cellWithOriginalXib.attachViewTopConstraint.constant ;
        // Handle user's picture
        NSString *avatarThumbURL = nil;
        if (bubbleData.senderAvatarUrl)
        {
            // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            avatarThumbURL = [bubbleData.mxSession.matrixRestClient urlOfContentThumbnail:bubbleData.senderAvatarUrl toFitViewSize:self.pictureView.frame.size withMethod:MXThumbnailingMethodCrop];
        }
        self.pictureView.enableInMemoryCache = YES;
        [self.pictureView setImageURL:avatarThumbURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
        [self.pictureView.layer setCornerRadius:self.pictureView.frame.size.width / 2];
        self.pictureView.clipsToBounds = YES;
        self.pictureView.backgroundColor = [UIColor redColor];
        
        // Listen to avatar tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAvatarTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.pictureView addGestureRecognizer:tapGesture];
        self.pictureView.userInteractionEnabled = YES;
        
        // Listen to textView tap
        tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMessageTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.messageTextView addGestureRecognizer:tapGesture];
        self.messageTextView.userInteractionEnabled = YES;
        
        // Adjust top constraint constant for dateTime labels container, and hide it by default
        if (bubbleData.attachment == nil || bubbleData.attachment.type == MXKAttachmentTypeFile)
        {
            self.bubbleInfoContainerTopConstraint.constant = self.msgTextViewTopConstraint.constant;
        }
        else
        {
            self.bubbleInfoContainerTopConstraint.constant = self.attachViewTopConstraint.constant;
        }
        self.bubbleInfoContainer.hidden = YES;
        
        // Set message content
        bubbleData.maxTextViewWidth = self.frame.size.width - (cellWithOriginalXib.msgTextViewLeadingConstraint.constant + cellWithOriginalXib.msgTextViewTrailingConstraint.constant);
        CGSize contentSize = bubbleData.contentSize;
        if (bubbleData.attachment && bubbleData.attachment.type != MXKAttachmentTypeFile)
        {
            self.messageTextView.hidden = YES;
            self.attachmentView.hidden = NO;
            
            self.attachmentView.backgroundColor = [UIColor clearColor];
            
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
            
            NSString *url = bubbleData.attachment.thumbnailURL;
            
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
            
            UIImage *preview = nil;
            if (bubbleData.attachment.previewURL)
            {
                NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:bubbleData.attachment.previewURL andType:mimetype inFolder:self.attachmentView.mediaFolder];
                preview = [MXKMediaManager loadPictureFromFilePath:cacheFilePath];
            }
            
            self.attachmentView.enableInMemoryCache = YES;
            [self.attachmentView setImageURL:url withType:mimetype andImageOrientation:bubbleData.attachment.thumbnailOrientation previewImage:preview];
            
            if (url && bubbleData.attachment.actualURL)
            {
                // Add tap recognizer to open attachment
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAttachmentTap:)];
                [tap setNumberOfTouchesRequired:1];
                [tap setNumberOfTapsRequired:1];
                [tap setDelegate:self];
                [self.attachmentView addGestureRecognizer:tap];
                
                // Prepare attachment description
                NSMutableDictionary *mediaInfoDict = [NSMutableDictionary dictionaryWithDictionary:@{@"attachmenttype" : [NSNumber numberWithUnsignedInt:bubbleData.attachment.type], @"url" : bubbleData.attachment.actualURL}];
                
                if (bubbleData.attachment.contentInfo)
                {
                    mediaInfoDict[@"info"] = bubbleData.attachment.contentInfo;
                }
                
                // Store attachment content description used in showAttachmentView:
                self.attachmentView.mediaInfo = mediaInfoDict;
            }
            
            [self startProgressUI];
            
            // Adjust Attachment width constant
            self.attachViewWidthConstraint.constant = contentSize.width;
            
            // Add a long gesture recognizer on attachment view in order to display event details
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.attachmentView addGestureRecognizer:longPress];
            // Add another long gesture recognizer on progressView to cancel the current operation (Note: only the download can be cancelled).
            longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.progressView addGestureRecognizer:longPress];
        }
        else
        {
            self.attachmentView.hidden = YES;
            self.playIconView.hidden = YES;
            self.fileTypeIconView.hidden = YES;
            self.messageTextView.hidden = NO;
            
            NSAttributedString* newText = nil;
            
            // Underline attached file name
            if (bubbleData.attachment && bubbleData.attachment.type == MXKAttachmentTypeFile && bubbleData.attachment.actualURL && bubbleData.attachment.contentInfo)
            {
                NSMutableAttributedString *updatedText = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
                [updatedText addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, updatedText.length)];
                
                newText = updatedText;
                
                // Add tap recognizer to open attachment
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAttachmentTap:)];
                [tap setNumberOfTouchesRequired:1];
                [tap setNumberOfTapsRequired:1];
                [tap setDelegate:self];
                [self.messageTextView addGestureRecognizer:tap];
                
                // Store attachment content description used in showAttachmentView:
                self.attachmentView.mediaInfo = @{
                                                  @"attachmenttype" : [NSNumber numberWithUnsignedInt:bubbleData.attachment.type],
                                                  @"url" : bubbleData.attachment.actualURL,
                                                  @"info" : bubbleData.attachment.contentInfo
                                                  };
            }
            else
            {
                newText = bubbleData.attributedTextMessage;
            }
            
            // update the text only if it is required
            // updating a text is quite long (even with the same text).
            // there is an heuristic herer : assume that the strings are equals if their texts are equal
            // (it is faster than coparing two attributed strings)
            if ((newText.length != self.messageTextView.attributedText.length) || ![newText.string isEqual:self.messageTextView.attributedText.string])
            {
                self.messageTextView.attributedText = newText;
            }
            
            // update the frame size from the content size
            // the content size is cached so it saved few ms
            // and avoid using sizeToFit
            CGRect newFrame, curframe;
            newFrame = curframe = CGRectIntegral(self.messageTextView.frame);
            newFrame.size = contentSize;
            
            // update the frame only if it is required
            // setting a frame is quite slow so avoid useless update.
            if (!CGRectEqualToRect(curframe, CGRectIntegral(newFrame)))
            {
                self.messageTextView.frame = newFrame;
            }
            
            // Add a long gesture recognizer on text view in order to display event details
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.messageTextView addGestureRecognizer:longPress];
        }
        
        // Check and update each component position (used to align timestamps label in front of events, and to handle tap gesture on events)
        [bubbleData prepareBubbleComponentsPosition];
        
        // Handle here timestamp display (only if a container has been defined)
        if (self.bubbleInfoContainer)
        {
            if ((bubbleData.showBubbleDateTime && !bubbleData.useCustomDateTimeLabel) || bubbleData.showBubbleReceipts)
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
                    if (component.event.mxkState != MXKEventStateSendingFailed)
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
                    
                        if (!bubbleData.isIncoming && bubbleData.showBubbleReceipts)
                        {
                            NSMutableArray* userIds = nil;
                            NSArray* receipts = nil;
                         
                            MXRoom* room = [bubbleData.mxSession roomWithRoomId:component.event.roomId];
                            
                            // get the events receipts
                            if (room)
                            {
                                receipts = [room getEventReceipts:component.event.eventId sorted:YES];
                            }
                            
                            // if some receipts are found
                            if (receipts)
                            {
                                NSString* myUserId = bubbleData.mxSession.myUser.userId;
                                NSMutableArray* res = [[NSMutableArray alloc] init];
                                
                                // remove the oneself receipts
                                for(MXReceiptData* data in receipts)
                                {
                                    if (![data.userId isEqualToString:myUserId])
                                    {
                                        [res addObject:data.userId];
                                    }
                                }
                                
                                if (res.count > 0)
                                {
                                    userIds = res;
                                }
                            }
                            
                            if (userIds)
                            {
                                MXKReceiptAvartarsContainer* avatarsContainer = [[MXKReceiptAvartarsContainer alloc] initWithFrame:CGRectMake(0, component.position.y + timeLabelOffset, self.bubbleInfoContainer.frame.size.width , 15)];
                                
                                [avatarsContainer setUserIds:userIds roomState:room.state session:bubbleData.mxSession placeholder:self.picturePlaceholder];
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
        }
    }
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
    
    // Compute height of message content (The maximum width available for the textview must be updated dynamically)
    bubbleData.maxTextViewWidth = maxWidth - (cell.msgTextViewLeadingConstraint.constant + cell.msgTextViewTrailingConstraint.constant);
    CGFloat rowHeight = bubbleData.contentSize.height;
    
    // Add top margin
    if (bubbleData.attachment == nil || bubbleData.attachment.type == MXKAttachmentTypeFile)
    {
        rowHeight += cell.msgTextViewTopConstraint.constant;
    }
    else
    {
        rowHeight += cell.attachViewTopConstraint.constant ;
    }
    
    return rowHeight;
}

- (void)didEndDisplay
{
    bubbleData = nil;
    
    // Remove all gesture recognizer
    while (self.attachmentView.gestureRecognizers.count)
    {
        [self.attachmentView removeGestureRecognizer:self.attachmentView.gestureRecognizers[0]];
    }
    
    // Remove potential dateTime (or unsent) label(s)
    if (self.bubbleInfoContainer.subviews.count > 0)
    {
        for (UIView *view in self.bubbleInfoContainer.subviews)
        {
            [view removeFromSuperview];
        }
    }
    
    [self stopProgressUI];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Remove long tap gesture on the progressView
    while (self.progressView.gestureRecognizers.count)
    {
        [self.progressView removeGestureRecognizer:self.progressView.gestureRecognizers[0]];
    }
    
    delegate = nil;
}

- (void)updateProgressUI:(NSDictionary*)statisticsDict
{
    self.progressView.hidden = !statisticsDict;
    
    NSString* downloadRate = [statisticsDict valueForKey:kMXKMediaLoaderProgressRateKey];
    NSString* remaingTime = [statisticsDict valueForKey:kMXKMediaLoaderProgressRemaingTimeKey];
    NSString* progressString = [statisticsDict valueForKey:kMXKMediaLoaderProgressStringKey];
    
    NSMutableString* text = [[NSMutableString alloc] init];
    
    if (progressString)
    {
        [text appendString:progressString];
    }
    
    if (downloadRate)
    {
        [text appendFormat:@"\n%@", downloadRate];
    }
    
    if (remaingTime)
    {
        [text appendFormat:@"\n%@", remaingTime];
    }
    
    self.statsLabel.text = text;
    
    NSNumber* progressNumber = [statisticsDict valueForKey:kMXKMediaLoaderProgressValueKey];
    
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
            
            // the job is really over
            if ([notif.name isEqualToString:kMXKMediaDownloadDidFinishNotification])
            {
                // remove any pending observers
                [[NSNotificationCenter defaultCenter] removeObserver:self];
            }
        }
    }
}

- (void)startProgressUI
{
    BOOL isHidden = YES;
    
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // there is an attachment URL
    if (bubbleData.attachment.actualURL)
    {
        // check if there is a download in progress
        MXKMediaLoader *loader = [MXKMediaManager existingDownloaderWithOutputFilePath:bubbleData.attachment.cacheFilePath];
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
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFinishNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFailNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadProgress:) name:kMXKMediaDownloadProgressNotification object:nil];
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
        if(childClasses == nil)
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
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnMessageTextView userInfo:nil];
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

- (IBAction)onLongPressGesture:(UILongPressGestureRecognizer*)longPressGestureRecognizer
{
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan && delegate)
    {
        UIView* view = longPressGestureRecognizer.view;
        
        // Check the view on which long press has been detected
        if (view == self.progressView)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnProgressView userInfo:nil];
        }
        else if (view == self.messageTextView || view == self.attachmentView)
        {
            MXEvent *selectedEvent = nil;
            if (bubbleData.bubbleComponents.count == 1)
            {
                MXKRoomBubbleComponent *component = [bubbleData.bubbleComponents firstObject];
                selectedEvent = component.event;
            }
            else if (bubbleData.bubbleComponents.count)
            {
                // Here the selected view is a textView (attachment has no more than one component)
                
                // Look for the selected component
                CGPoint longPressPoint = [longPressGestureRecognizer locationInView:view];
                for (MXKRoomBubbleComponent *component in bubbleData.bubbleComponents)
                {
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
    }
}

@end
