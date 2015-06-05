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

#import "MXKAccountTableViewCell.h"

#import "MXKMediaManager.h"

@implementation MXKAccountTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKAccountTableViewCell class]] loadNibNamed:NSStringFromClass([MXKAccountTableViewCell class])
                                                                                          owner:nil
                                                                                        options:nil];
    self = nibViews.firstObject;
    return self;
}

- (void)setMxAccount:(MXKAccount *)mxAccount
{
    UIColor *presenceColor = nil;
    
    if (mxAccount.mxSession)
    {
        
        _accountDisplayName.text = mxAccount.fullDisplayName;
        
        // User thumbnail
        NSString *thumbnailURL = nil;
        if (mxAccount.userAvatarUrl)
        {
            // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            thumbnailURL = [mxAccount.mxSession.matrixRestClient urlOfContentThumbnail:mxAccount.userAvatarUrl toFitViewSize:_accountPicture.frame.size withMethod:MXThumbnailingMethodCrop];
        }
        _accountPicture.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
        [_accountPicture setImageURL:thumbnailURL withImageOrientation:UIImageOrientationUp andPreviewImage:[UIImage imageNamed:@"default-profile"]];
        
        presenceColor = [MXKAccount presenceColor:mxAccount.userPresence];
        
    }
    else
    {
        _accountDisplayName.text = nil;
        _accountPicture.image = [UIImage imageNamed:@"default-profile"];
    }
    
    
    
    if (presenceColor)
    {
        _accountPicture.layer.borderWidth = 2;
        _accountPicture.layer.borderColor = presenceColor.CGColor;
    }
    else
    {
        _accountPicture.layer.borderWidth = 0;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Round image view
    [_accountPicture.layer setCornerRadius:_accountPicture.frame.size.width / 2];
    _accountPicture.clipsToBounds = YES;
}

@end
