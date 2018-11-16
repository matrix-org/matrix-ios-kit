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

#import "MXKSampleJSQMessageMediaData.h"

#import "MXKImageView.h"

#import "JSQMessagesMediaViewBubbleImageMasker.h"

@interface MXKSampleJSQMessageMediaData ()
{
    MXKRoomBubbleCellData *cellData;
}

@end

@implementation MXKSampleJSQMessageMediaData

- (instancetype)initWithCellData:(MXKRoomBubbleCellData *)cellData2
{
    self = [super init];
    if (self)
    {
        
        cellData = cellData2;
    }
    return self;
}

- (UIView *)mediaView
{
    NSString *mimetype = nil;
    if (cellData.attachment.thumbnailInfo)
    {
        mimetype = cellData.attachment.thumbnailInfo[@"mimetype"];
    }
    else if (cellData.attachment.contentInfo)
    {
        mimetype = cellData.attachment.contentInfo[@"mimetype"];
    }
    
    // MXKImageView will automatically download and cache the media thumbnail
    MXKImageView *imageView = [[MXKImageView alloc] initWithFrame:CGRectMake(0, 0, cellData.contentSize.width, cellData.contentSize.height)];
    [imageView setImageURI:cellData.attachment.mxcThumbnailURI withType:mimetype andImageOrientation:cellData.attachment.thumbnailOrientation previewImage:nil mediaManager:cellData.mxSession.mediaManager];

    
    // Use transparent color while downloading the media
    imageView.backgroundColor = [UIColor clearColor];
    
    // Put the image view into a JSQMessages bubble
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:imageView isOutgoing:!cellData.isIncoming];
    
    return imageView;
}

- (CGSize)mediaViewDisplaySize
{
    // Return the thumbnail size
    return cellData.contentSize;
}

- (UIView *)mediaPlaceholderView
{
    // The MXKImageView returned by [self mediaView] is supposed to do the job
    return nil;
}

- (NSUInteger)mediaHash
{
    return self.mediaHash;
}

@end
