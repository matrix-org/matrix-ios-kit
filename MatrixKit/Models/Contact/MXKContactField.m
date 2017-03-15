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

#import "MXKContactField.h"

#import "MXMediaManager.h"
#import "MXKContactManager.h"

@interface MXKContactField()
{
    NSString* avatarURL;
}
@end

@implementation MXKContactField

- (void)initFields
{
    // init members
    _contactID = nil;
    _matrixID = nil;
    
    [self resetMatrixAvatar];
}

- (id)initWithContactID:(NSString*)contactID matrixID:(NSString*)matrixID
{
    self = [super init];
    
    if (self)
    {
        [self initFields];
        _contactID = contactID;
        _matrixID = matrixID;
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)resetMatrixAvatar
{
    _avatarImage = nil;
    _matrixAvatarURL = nil;
    avatarURL = @"";
}

- (void)loadAvatarWithSize:(CGSize)avatarSize
{
    // Check whether the avatar image is already set
    if (_avatarImage)
    {
        return;
    }
    
    // Sanity check
    if (_matrixID)
    {
        // nil -> there is no avatar
        if (!avatarURL)
        {
            return;
        }
        
        // Empty string means not yet initialized
        if (avatarURL.length > 0)
        {
            [self downloadAvatarImage];
        }
        else
        {
            // Consider here all sessions reported into contact manager
            NSArray* mxSessions = [MXKContactManager sharedManager].mxSessions;
            
            if (mxSessions.count)
            {
                // Check whether a matrix user is already known
                MXUser* user;
                
                for (MXSession *mxSession in mxSessions)
                {
                    user = [mxSession userWithUserId:_matrixID];
                    if (user)
                    {
                        _matrixAvatarURL = user.avatarUrl;
                        
                        avatarURL = [mxSession.matrixRestClient urlOfContentThumbnail:_matrixAvatarURL toFitViewSize:avatarSize withMethod:MXThumbnailingMethodCrop];
                        
                        [self downloadAvatarImage];
                        break;
                    }
                }
                
                
                if (!user)
                {
                    MXSession *mxSession = mxSessions.firstObject;
                    [mxSession.matrixRestClient avatarUrlForUser:_matrixID
                                                         success:^(NSString *mxAvatarUrl) {
                                                             
                        _matrixAvatarURL = mxAvatarUrl;
                        
                        avatarURL = [mxSession.matrixRestClient urlOfContentThumbnail:_matrixAvatarURL toFitViewSize:avatarSize withMethod:MXThumbnailingMethodCrop];
                                                             
                        [self downloadAvatarImage];
                                                             
                    } failure:nil];
                }
            }
        }
    }
}

- (void)downloadAvatarImage
{
    // the avatar image is already done
    if (_avatarImage)
    {
        return;
    }
    
    if (avatarURL.length > 0)
    {
        NSString *cacheFilePath = [MXMediaManager cachePathForMediaWithURL:avatarURL andType:nil inFolder:kMXMediaManagerAvatarThumbnailFolder];
        
        _avatarImage = [MXMediaManager loadPictureFromFilePath:cacheFilePath];
        
        // the image is already in the cache
        if (_avatarImage)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactThumbnailUpdateNotification object:_contactID userInfo:nil];
            });
        }
        else
        {
            
            MXMediaLoader* loader = [MXMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
            
            if (!loader)
            {
                [MXMediaManager downloadMediaFromURL:avatarURL andSaveAtFilePath:cacheFilePath];
            }
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXMediaDownloadDidFinishNotification object:nil];
        }
    }
}

- (void)onMediaDownloadEnd:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* url = notif.object;
        NSString* cacheFilePath = notif.userInfo[kMXMediaLoaderFilePathKey];
        
        if ([url isEqualToString:avatarURL] && cacheFilePath.length)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaDownloadDidFinishNotification object:nil];
            
            // update the image
            UIImage* image = [MXMediaManager loadPictureFromFilePath:cacheFilePath];
            if (image)
            {
                _avatarImage = image;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactThumbnailUpdateNotification object:_contactID userInfo:nil];
                });
            }
        }
    }
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    if (self)
    {
        [self initFields];
        _contactID = [coder decodeObjectForKey:@"contactID"];
        _matrixID = [coder decodeObjectForKey:@"matrixID"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_contactID forKey:@"contactID"];
    [coder encodeObject:_matrixID forKey:@"matrixID"];
}

@end
