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

#import "MXKAccountTableViewCell.h"

#import "MXMediaManager.h"

#import "NSBundle+MatrixKit.h"

@implementation MXKAccountTableViewCell

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    self.accountPicture.defaultBackgroundColor = [UIColor clearColor];
}

- (void)setMxAccount:(MXKAccount *)mxAccount
{
    UIColor *presenceColor = nil;
    
    _accountDisplayName.text = mxAccount.fullDisplayName;
    
    if (mxAccount.mxSession)
    {
        // User thumbnail
        NSString *thumbnailURL = nil;
        if (mxAccount.userAvatarUrl)
        {
            // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            thumbnailURL = [mxAccount.mxSession.matrixRestClient urlOfContentThumbnail:mxAccount.userAvatarUrl toFitViewSize:_accountPicture.frame.size withMethod:MXThumbnailingMethodCrop];
        }
        _accountPicture.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        _accountPicture.enableInMemoryCache = YES;
        [_accountPicture setImageURL:thumbnailURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
        
        presenceColor = [MXKAccount presenceColor:mxAccount.userPresence];
    }
    else
    {
        _accountPicture.image = self.picturePlaceholder;
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
    
    _accountSwitchToggle.on = !mxAccount.disabled;
    if (mxAccount.disabled)
    {
        _accountDisplayName.textColor = [UIColor lightGrayColor];
    }
    else
    {
        _accountDisplayName.textColor = [UIColor blackColor];
    }
    
    _mxAccount = mxAccount;
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Round image view
    [_accountPicture.layer setCornerRadius:_accountPicture.frame.size.width / 2];
    _accountPicture.clipsToBounds = YES;
}

@end
