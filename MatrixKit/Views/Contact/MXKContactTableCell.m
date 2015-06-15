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

#import "MXKContactTableCell.h"

#import "MXKContactManager.h"
#import "MXKAppSettings.h"
#import "MXTools.h"

#import "NSBundle+MatrixKit.h"

#pragma mark - Constant definitions
NSString *const kMXKContactCellTapOnThumbnailView = @"kMXKContactCellTapOnThumbnailView";

NSString *const kMXKContactCellContactIdKey = @"kMXKContactCellContactIdKey";


@interface MXKContactTableCell()
{
    /**
     The current displayed contact.
     */
    MXKContact *contact;
    
    /**
     The observer of the presence for matrix user.
     */
    id mxPresenceObserver;
}
@end

@implementation MXKContactTableCell
@synthesize delegate;

+ (UINib *)nib
{
    // By default, no nib is available.
    return nil;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKContactTableCell class]] loadNibNamed:NSStringFromClass([MXKContactTableCell class])
                                                                                             owner:nil
                                                                                           options:nil];
    self = nibViews.firstObject;
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.thumbnailView.backgroundColor = [UIColor clearColor];
    self.matrixUserIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"matrixUser"];
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

#pragma mark - MXKCellRendering

- (void)render:(MXKCellData *)cellData
{
    // Sanity check: accept only object of MXKContact classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKContact class]]);
    
    contact = (MXKContact*)cellData;
    
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (mxPresenceObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:mxPresenceObserver];
        mxPresenceObserver = nil;
    }
    
    self.thumbnailView.layer.borderWidth = 0;
    
    if (contact) {
        // Be warned when the thumbnail is updated
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThumbnailUpdate:) name:kMXKContactThumbnailUpdateNotification object:nil];
        
        // Observe contact presence change
        mxPresenceObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKContactManagerMatrixUserPresenceChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // get the matrix identifiers
            NSArray* matrixIdentifiers = contact.matrixIdentifiers;
            if (matrixIdentifiers.count > 0)
            {
                // Consider only the first id
                NSString *matrixUserID = matrixIdentifiers.firstObject;
                if ([matrixUserID isEqualToString:notif.object])
                {
                    [self refreshPresenceUserRing:[MXTools presence:[notif.userInfo objectForKey:kMXKContactManagerMatrixPresenceKey]]];
                }
            }
        }];
        
        if (!contact.isMatrixContact) {
            // Be warned when the linked matrix IDs are updated
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixIdUpdate:)  name:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:nil];
            
            // Refresh matrix info of the contact
            [[MXKContactManager sharedManager] updateMatrixIDsForLocalContact:contact];
        }
        
        NSArray* matrixIDs = contact.matrixIdentifiers;
        
        if (matrixIDs.count)
        {
            self.contactDisplayNameLabel.hidden = YES;
            
            self.matrixDisplayNameLabel.hidden = NO;
            self.matrixDisplayNameLabel.text = contact.displayName;
            self.matrixIDLabel.hidden = NO;
            self.matrixIDLabel.text = [matrixIDs firstObject];
        }
        else
        {
            self.contactDisplayNameLabel.hidden = NO;
            self.contactDisplayNameLabel.text = contact.displayName;
            
            self.matrixDisplayNameLabel.hidden = YES;
            self.matrixIDLabel.hidden = YES;
        }
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onContactThumbnailTap:)];
        [tap setNumberOfTouchesRequired:1];
        [tap setNumberOfTapsRequired:1];
        [tap setDelegate:self];
        [self.thumbnailView addGestureRecognizer:tap];
    }
    
    [self refreshContactThumbnail];
    [self manageMatrixIcon];
}

+ (CGFloat)heightForCellData:(MXKCellData*)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 50;
}

- (void)didEndDisplay
{
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (mxPresenceObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:mxPresenceObserver];
        mxPresenceObserver = nil;
    }
    
    // Remove all gesture recognizer
    while (self.thumbnailView.gestureRecognizers.count)
    {
        [self.thumbnailView removeGestureRecognizer:self.thumbnailView.gestureRecognizers[0]];
    }
    
    self.delegate = nil;
    contact = nil;
}

#pragma mark -

- (void)refreshUserPresence
{
    // Look for a potential matrix user linked with this contact
    NSArray* matrixIdentifiers = contact.matrixIdentifiers;
    if (matrixIdentifiers.count > 0)
    {
        // Consider only the first matrix identifier
        NSString* matrixUserID = matrixIdentifiers.firstObject;
        
        // Consider here all sessions reported into contact manager
        NSArray* mxSessions = [MXKContactManager sharedManager].mxSessions;
        for (MXSession *mxSession in mxSessions)
        {
            MXUser *mxUser = [mxSession userWithUserId:matrixUserID];
            if (mxUser)
            {
                [self refreshPresenceUserRing:mxUser.presence];
                break;
            }
        }
        
        // we know that this user is a matrix one
        self.matrixUserIconView.hidden = NO;
    }
}

- (void)refreshContactThumbnail
{
    self.thumbnailView.image = [contact thumbnailWithPreferedSize:self.thumbnailView.frame.size];
    
    if (!self.thumbnailView.image)
    {
        self.thumbnailView.image = self.picturePlaceholder;
    }
    
    // display the thumbnail in a circle
    if (self.thumbnailView.layer.cornerRadius  != self.thumbnailView.frame.size.width / 2)
    {
        self.thumbnailView.layer.cornerRadius = self.thumbnailView.frame.size.width / 2;
        self.thumbnailView.clipsToBounds = YES;
    }
}

- (void)refreshPresenceUserRing:(MXPresence)presenceStatus
{
    UIColor* ringColor;
    
    switch (presenceStatus)
    {
        case MXPresenceOnline:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForOnlineUser];
            break;
        case MXPresenceUnavailable:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForUnavailableUser];
            break;
        case MXPresenceOffline:
            ringColor = [[MXKAppSettings standardAppSettings] presenceColorForOfflineUser];
            break;
        default:
            ringColor = nil;
    }
    
    // if the thumbnail is defined
    if (ringColor)
        
    {
        self.thumbnailView.layer.borderWidth = 2;
        self.thumbnailView.layer.borderColor = ringColor.CGColor;
    }
    else
    {
        // remove the border
        // else it draws black border
        self.thumbnailView.layer.borderWidth = 0;
    }
}

- (void)manageMatrixIcon
{
    self.matrixUserIconView.hidden = (0 == contact.matrixIdentifiers.count);
    
    // try to update the thumbnail with the matrix thumbnail
    if (contact.matrixIdentifiers)
    {
        [self refreshContactThumbnail];
    }
    
    [self refreshUserPresence];
}

- (void)onMatrixIdUpdate:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* contactID = notif.object;
        
        if ([contactID isEqualToString:contact.contactID])
        {
            [self manageMatrixIcon];
        }
    }
}

- (void)onThumbnailUpdate:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* contactID = notif.object;
        
        if ([contactID isEqualToString:contact.contactID])
        {
            [self refreshContactThumbnail];
            self.matrixUserIconView.hidden = (0 == contact.matrixIdentifiers.count);
            
            [self refreshUserPresence];
        }
    }
}

#pragma mark - Action

- (IBAction)onContactThumbnailTap:(id)sender
{
    if (self.delegate)
    {
        [self.delegate cell:self didRecognizeAction:kMXKContactCellTapOnThumbnailView userInfo:@{kMXKContactCellContactIdKey: contact.contactID}];
    }
}

@end