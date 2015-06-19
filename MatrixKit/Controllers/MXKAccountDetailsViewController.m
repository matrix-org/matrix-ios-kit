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

#import "MXKAccountDetailsViewController.h"

#import "MXKMediaLoader.h"
#import "MXK3PID.h"
#import "MXKAlert.h"

#import "MXKMediaManager.h"
#import "MXKTools.h"

#import "MXKTableViewCell.h"

#import "NSBundle+MatrixKit.h"

NSString* const kMXKAccountDetailsConfigurationFormatText = @"Home server: %@\r\nIdentity server: %@\r\nUser ID: %@";

NSString *const kMXKAccountDetailsLinkedEmailCellId = @"kMXKAccountDetailsLinkedEmailCellId";
NSString *const kMXKAccountDetailsSubmittedEmailCellId = @"kMXKAccountDetailsSubmittedEmailCellId";
NSString *const kMXKAccountDetailsEmailTokenCellId = @"kMXKAccountDetailsEmailTokenCellId";

NSString *const kMXKAccountDetailsCellWithTextViewId = @"kMXKAccountDetailsCellWithTextViewId";
NSString *const kMXKAccountDetailsCellWithSwitchId = @"kMXKAccountDetailsCellWithSwitchId";
NSString *const kMXKAccountDetailsCellWithButtonId = @"kMXKAccountDetailsCellWithButtonId";

NSString* const kUserInfoNotificationRulesText = @"To configure global notification settings (like rules), go find a webclient and hit Settings > Notifications.";

@interface MXKAccountDetailsViewController ()
{
    NSMutableArray *alertsArray;
    
    // Section index
    NSInteger linkedEmailsSection;
    NSInteger notificationsSection;
    NSInteger configurationSection;
    
    // The table cell with logout button
    MXKTableViewCellWithButton *logoutBtnCell;
    
    // User's profile
    MXKMediaLoader *imageLoader;
    NSString *currentDisplayName;
    NSString *currentPictureURL;
    NSString *currentPictureThumbURL;
    NSString *uploadedPictureURL;
    // Local changes
    BOOL isAvatarUpdated;
    BOOL isSavingInProgress;
    blockMXKAccountDetailsViewController_onReadyToLeave onReadyToLeaveHandler;
    
    // account user's profile observer
    id accountUserInfoObserver;
    
    // Linked emails
    // TODO: When server will provide existing linked emails, these linked emails should be stored in MXKAccount instance.
    NSMutableArray *linkedEmails;
    
    MXK3PID        *submittedEmail;
    MXKTableViewCellWithTextFieldAndButton* submittedEmailCell;
    MXKTableViewCellWithLabelTextFieldAndButton* emailTokenCell;
    // Dynamic rows in the Linked emails section
    NSInteger submittedEmailRowIndex;
    NSInteger emailTokenRowIndex;
    
    // Notifications
    UISwitch *apnsNotificationsSwitch;
    UISwitch *inAppNotificationsSwitch;
    // Dynamic rows in the Notifications section
    NSInteger enablePushNotifRowIndex;
    NSInteger enableInAppNotifRowIndex;
    NSInteger userInfoNotifRowIndex;
    
    UIImagePickerController *mediaPicker;
}

@end

@implementation MXKAccountDetailsViewController
@synthesize userPictureButton, userDisplayName, saveUserInfoButton;
@synthesize profileActivityIndicator, profileActivityIndicatorBgView;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKAccountDetailsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKAccountDetailsViewController class]]];
}

+ (instancetype)accountDetailsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKAccountDetailsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKAccountDetailsViewController class]]];
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!userPictureButton)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    self.userPictureButton.backgroundColor = [UIColor clearColor];
    [self updateUserPictureButton:self.picturePlaceholder];
    
    alertsArray = [NSMutableArray array];
    
    isAvatarUpdated = NO;
    isSavingInProgress = NO;
    
    [userPictureButton.layer setCornerRadius:userPictureButton.frame.size.width / 2];
    userPictureButton.clipsToBounds = YES;
    
    // Force refresh
    self.mxAccount = _mxAccount;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    if (imageLoader)
    {
        [imageLoader cancel];
        imageLoader = nil;
    }
}

- (void)dealloc
{
    alertsArray = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAPNSStatusUpdate) name:kMXKAccountAPNSActivityDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self stopProfileActivityIndicator];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKAccountAPNSActivityDidChangeNotification object:nil];
}

#pragma mark - override

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    if (self.mainSession.state != MXSessionStateRunning)
    {
        userPictureButton.enabled = NO;
        userDisplayName.enabled = NO;
    }
    else if (!isSavingInProgress)
    {
        userPictureButton.enabled = YES;
        userDisplayName.enabled = YES;
    }
}

#pragma mark -

- (void)setMxAccount:(MXKAccount *)account
{
    // Remove observer and existing data
    [self reset];
    
    _mxAccount = account;
    
    if (account)
    {
        // Report matrix account session
        [self addMatrixSession:account.mxSession];
        
        // Set current user's information and add observers
        [self updateUserPicture:_mxAccount.userAvatarUrl force:YES];
        currentDisplayName = _mxAccount.userDisplayName;
        self.userDisplayName.text = currentDisplayName;
        [self updateSaveUserInfoButtonStatus];
        
        // Add observer on user's information
        accountUserInfoObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountUserInfoDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            // Ignore any refresh when saving is in progress
            if (isSavingInProgress)
            {
                return;
            }
            
            NSString *accountUserId = notif.object;
            
            if ([accountUserId isEqualToString:_mxAccount.mxCredentials.userId])
            {   
                // Update displayName
                if (![currentDisplayName isEqualToString:_mxAccount.userDisplayName])
                {
                    currentDisplayName = _mxAccount.userDisplayName;
                    self.userDisplayName.text = _mxAccount.userDisplayName;
                }
                // Update user's avatar
                [self updateUserPicture:_mxAccount.userAvatarUrl force:NO];
                
                // Update button management
                [self updateSaveUserInfoButtonStatus];
                
                // Display user's presence
                UIColor *presenceColor = [MXKAccount presenceColor:_mxAccount.userPresence];
                if (presenceColor)
                {
                    userPictureButton.layer.borderWidth = 2;
                    userPictureButton.layer.borderColor = presenceColor.CGColor;
                }
                else
                {
                    userPictureButton.layer.borderWidth = 0;
                }
            }
        }];
    }
    
    [self.tableView reloadData];
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (BOOL)shouldLeave:(blockMXKAccountDetailsViewController_onReadyToLeave)handler
{
    // Check whether some local changes have not been saved
    if (saveUserInfoButton.enabled)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            MXKAlert *alert = [[MXKAlert alloc] initWithTitle:nil message:@"Changes will be discarded"  style:MXKAlertStyleAlert];
            [alertsArray addObject:alert];
            alert.cancelButtonIndex = [alert addActionWithTitle:@"Discard" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                                       {
                                           [alertsArray removeObject:alert];
                                           // Discard changes
                                           self.userDisplayName.text = currentDisplayName;
                                           [self updateUserPicture:_mxAccount.userAvatarUrl force:YES];
                                           
                                           // Ready to leave
                                           if (handler)
                                           {
                                               handler();
                                           }
                                       }];
            [alert addActionWithTitle:@"Save" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
             {
                 [alertsArray removeObject:alert];
                 
                 // Start saving (Report handler to leave at the end).
                 onReadyToLeaveHandler = handler;
                 [self saveUserInfo];
             }];
            [alert showInViewController:self];
        });
        
        return NO;
    }
    else if (isSavingInProgress)
    {
        // Report handler to leave at the end of saving
        onReadyToLeaveHandler = handler;
        return NO;
    }
    return YES;
}

#pragma mark - Internal methods

- (void)startProfileActivityIndicator
{
    if (profileActivityIndicatorBgView.hidden)
    {
        profileActivityIndicatorBgView.hidden = NO;
        [profileActivityIndicator startAnimating];
    }
    userPictureButton.enabled = NO;
    userDisplayName.enabled = NO;
    saveUserInfoButton.enabled = NO;
}

- (void)stopProfileActivityIndicator
{
    if (!isSavingInProgress)
    {
        if (!profileActivityIndicatorBgView.hidden)
        {
            profileActivityIndicatorBgView.hidden = YES;
            [profileActivityIndicator stopAnimating];
        }
        userPictureButton.enabled = YES;
        userDisplayName.enabled = YES;
        [self updateSaveUserInfoButtonStatus];
    }
}

- (void)reset
{
    [self dismissMediaPicker];
    
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Cancel picture loader (if any)
    if (imageLoader)
    {
        [imageLoader cancel];
        imageLoader = nil;
    }
    
    // Cancel potential alerts
    for (MXKAlert *alert in alertsArray){
        [alert dismiss:NO];
    }
    
    // Remove listener
    if (accountUserInfoObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:accountUserInfoObserver];
        accountUserInfoObserver = nil;
    }
    
    currentPictureURL = nil;
    currentPictureThumbURL = nil;
    uploadedPictureURL = nil;
    isAvatarUpdated = NO;
    [self updateUserPictureButton:self.picturePlaceholder];
    
    currentDisplayName = nil;
    self.userDisplayName.text = nil;
    
    saveUserInfoButton.enabled = NO;
    
    linkedEmails = nil;
    submittedEmail = nil;
    submittedEmailCell = nil;
    emailTokenCell = nil;
    
    [self removeMatrixSession:self.mainSession];
    
    logoutBtnCell = nil;
    
    onReadyToLeaveHandler = nil;
}

- (void)destroy
{
    if (isSavingInProgress)
    {
        __weak typeof(self) weakSelf = self;
        onReadyToLeaveHandler = ^()
        {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf destroy];
        };
    }
    else
    {
        // Reset account to dispose all resources (Discard here potentials changes)
        self.mxAccount = nil;
        
        [super destroy];
    }
}

- (void)saveUserInfo
{
    [self startProfileActivityIndicator];
    isSavingInProgress = YES;
    
    // Check whether the display name has been changed
    NSString *displayname = self.userDisplayName.text;
    if ((displayname.length || currentDisplayName.length) && [displayname isEqualToString:currentDisplayName] == NO)
    {
        
        // Save display name
        __weak typeof(self) weakSelf = self;
        [_mxAccount setUserDisplayName:displayname success:^{
            
            // Update the current displayname
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->currentDisplayName = displayname;
            
            // Go to the next change saving step
            [strongSelf saveUserInfo];
            
        } failure:^(NSError *error)
         {
             
             NSLog(@"[MXKAccountDetailsVC] Failed to set displayName: %@", error);
             __strong __typeof(weakSelf)strongSelf = weakSelf;
             
             //Alert user
             NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
             if (!title)
             {
                 title = @"Display name change failed";
             }
             NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
             
             MXKAlert *alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
             [strongSelf->alertsArray addObject:alert];
             alert.cancelButtonIndex = [alert addActionWithTitle:@"Abort" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                                        {
                                            [strongSelf->alertsArray removeObject:alert];
                                            // Discard changes
                                            strongSelf.userDisplayName.text = strongSelf->currentDisplayName;
                                            [strongSelf updateUserPicture:strongSelf.mxAccount.userAvatarUrl force:YES];
                                            // Loop to end saving
                                            [strongSelf saveUserInfo];
                                        }];
             [alert addActionWithTitle:@"Retry" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
              {
                  [strongSelf->alertsArray removeObject:alert];
                  // Loop to retry saving
                  [strongSelf saveUserInfo];
              }];
             [alert showInViewController:strongSelf];
         }];
        
        return;
    }
    
    // Check whether avatar has been updated
    if (isAvatarUpdated)
    {
        if (uploadedPictureURL == nil)
        {
            // Retrieve the current picture and make sure its orientation is up
            UIImage *updatedPicture = [MXKTools forceImageOrientationUp:[self.userPictureButton imageForState:UIControlStateNormal]];
            
            // Upload picture
            MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mainSession initialRange:0 andRange:1.0];
            [uploader uploadData:UIImageJPEGRepresentation(updatedPicture, 0.5) mimeType:@"image/jpeg" success:^(NSString *url)
             {
                 // Store uploaded picture url and trigger picture saving
                 uploadedPictureURL = url;
                 [self saveUserInfo];
             } failure:^(NSError *error)
             {
                 NSLog(@"[MXKAccountDetailsVC] Failed to upload image: %@", error);
                 [self handleErrorDuringPictureSaving:error];
             }];
            
        }
        else
        {
            __weak typeof(self) weakSelf = self;
            [_mxAccount setUserAvatarUrl:uploadedPictureURL
                                 success:^{
                                     
                                     // uploadedPictureURL becomes the user's picture
                                     __strong __typeof(weakSelf)strongSelf = weakSelf;
                                     [strongSelf updateUserPicture:strongSelf->uploadedPictureURL force:YES];
                                     // Loop to end saving
                                     [strongSelf saveUserInfo];
                                     
                                 }
                                 failure:^(NSError *error) {
                                     NSLog(@"[MXKAccountDetailsVC] Failed to set avatar url: %@", error);
                                     __strong __typeof(weakSelf)strongSelf = weakSelf;
                                     [strongSelf handleErrorDuringPictureSaving:error];
                                 }];
        }
        
        return;
    }
    
    // Backup is complete
    isSavingInProgress = NO;
    [self stopProfileActivityIndicator];
    
    // Ready to leave
    if (onReadyToLeaveHandler)
    {
        onReadyToLeaveHandler();
        onReadyToLeaveHandler = nil;
    }
}

- (void)handleErrorDuringPictureSaving:(NSError*)error
{
    NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
    if (!title)
    {
        title = @"Picture change failed";
    }
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    
    MXKAlert *alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
    [alertsArray addObject:alert];
    alert.cancelButtonIndex = [alert addActionWithTitle:@"Abort" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                               {
                                   [alertsArray removeObject:alert];
                                   // Remove change
                                   self.userDisplayName.text = currentDisplayName;
                                   [self updateUserPicture:_mxAccount.userAvatarUrl force:YES];
                                   // Loop to end saving
                                   [self saveUserInfo];
                               }];
    [alert addActionWithTitle:@"Retry" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
     {
         [alertsArray removeObject:alert];
         // Loop to retry saving
         [self saveUserInfo];
     }];
    
    [alert showInViewController:self];
}

- (void)updateUserPicture:(NSString *)avatar_url force:(BOOL)force
{
    if (force || currentPictureURL == nil || [currentPictureURL isEqualToString:avatar_url] == NO)
    {
        // Remove any pending observers
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        // Cancel previous loader (if any)
        if (imageLoader)
        {
            [imageLoader cancel];
            imageLoader = nil;
        }
        // Cancel any local change
        isAvatarUpdated = NO;
        uploadedPictureURL = nil;
        
        currentPictureURL = [avatar_url isEqual:[NSNull null]] ? nil : avatar_url;
        if (currentPictureURL)
        {
            // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            currentPictureThumbURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:currentPictureURL toFitViewSize:self.userPictureButton.frame.size withMethod:MXThumbnailingMethodCrop];
            NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:currentPictureThumbURL inFolder:kMXKMediaManagerAvatarThumbnailFolder];
            
            // Check whether the image download is in progress
            id loader = [MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
            if (loader)
            {
                // Add observers
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFinishNotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFailNotification object:nil];
            }
            else
            {
                // Retrieve the image from cache
                UIImage* image = [MXKMediaManager loadPictureFromFilePath:cacheFilePath];
                if (image)
                {
                    [self updateUserPictureButton:image];
                }
                else
                {
                    // Cancel potential download in progress
                    if (imageLoader)
                    {
                        [imageLoader cancel];
                    }
                    // Add observers
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFinishNotification object:nil];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFailNotification object:nil];
                    imageLoader = [MXKMediaManager downloadMediaFromURL:currentPictureThumbURL andSaveAtFilePath:cacheFilePath];
                }
            }
        }
        else
        {
            // Set placeholder
            [self updateUserPictureButton:self.picturePlaceholder];
        }
    }
}

- (void)updateUserPictureButton:(UIImage*)image
{
    [self.userPictureButton setImage:image forState:UIControlStateNormal];
    [self.userPictureButton setImage:image forState:UIControlStateHighlighted];
    [self.userPictureButton setImage:image forState:UIControlStateDisabled];
}

- (void)updateSaveUserInfoButtonStatus
{
    // Check whether display name has been changed
    NSString *displayname = self.userDisplayName.text;
    BOOL isDisplayNameUpdated = ((displayname.length || currentDisplayName.length) && [displayname isEqualToString:currentDisplayName] == NO);
    
    saveUserInfoButton.enabled = (isDisplayNameUpdated || isAvatarUpdated) && !isSavingInProgress;
}

- (void)onMediaDownloadEnd:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* url = notif.object;
        NSString* cacheFilePath = notif.userInfo[kMXKMediaLoaderFilePathKey];
        
        if ([url isEqualToString:currentPictureThumbURL])
        {
            // update the image
            UIImage* image = nil;
            
            if (cacheFilePath.length)
            {
                image = [MXKMediaManager loadPictureFromFilePath:cacheFilePath];
            }
            if (image == nil)
            {
                image = self.picturePlaceholder;
            }
            [self updateUserPictureButton:image];
            
            // remove the observers
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            imageLoader = nil;
            
            if ([notif.name isEqualToString:kMXKMediaDownloadDidFailNotification])
            {
                // Reset picture URL in order to try next time
                currentPictureURL = nil;
            }
        }
    }
}

- (void)onAPNSStatusUpdate
{
    // Force table reload to update notifications section
    apnsNotificationsSwitch = nil;
    
    [self.tableView reloadData];
}

- (void)dismissMediaPicker
{
    if (mediaPicker)
    {
        [self dismissViewControllerAnimated:NO completion:nil];
        mediaPicker.delegate = nil;
        mediaPicker = nil;
    }
}

#pragma mark - Actions

- (IBAction)onButtonPressed:(id)sender
{
    [self dismissKeyboard];
    
    if (sender == saveUserInfoButton)
    {
        [self saveUserInfo];
    }
    else if (sender == userPictureButton)
    {
        // Open picture gallery
        mediaPicker = [[UIImagePickerController alloc] init];
        mediaPicker.delegate = self;
        mediaPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        mediaPicker.allowsEditing = NO;
        [self presentViewController:mediaPicker animated:YES completion:nil];
    }
    else if (sender == logoutBtnCell.mxkButton)
    {
        [[MXKAccountManager sharedManager] removeAccount:_mxAccount];
        self.mxAccount = nil;
    }
    else if (sender == submittedEmailCell.mxkButton)
    {
        if (!submittedEmail || ![submittedEmail.address isEqualToString:submittedEmailCell.mxkTextField.text])
        {
            submittedEmail = [[MXK3PID alloc] initWithMedium:kMX3PIDMediumEmail andAddress:submittedEmailCell.mxkTextField.text];
        }
        
        submittedEmailCell.mxkButton.enabled = NO;
        [submittedEmail requestValidationTokenWithMatrixRestClient:self.mainSession.matrixRestClient success:^{
            // Reset email field
            submittedEmailCell.mxkTextField.text = nil;
            [self.tableView reloadData];
        } failure:^(NSError *error)
         {
             NSLog(@"[MXKAccountDetailsVC] Failed to request email token: %@", error);
             //Alert user TODO GFO
             //            [[AppDelegate theDelegate] showErrorAsAlert:error];
             submittedEmailCell.mxkButton.enabled = YES;
         }];
    }
    else if (sender == emailTokenCell.mxkButton)
    {
        emailTokenCell.mxkButton.enabled = NO;
        [submittedEmail validateWithToken:emailTokenCell.mxkTextField.text success:^(BOOL success)
         {
             if (success)
             {
                 // The email has been "Authenticated"
                 // Link the email with user's account
                 [submittedEmail bindWithUserId:_mxAccount.mxCredentials.userId success:^{
                     // Add new linked email
                     if (!linkedEmails)
                     {
                         linkedEmails = [NSMutableArray array];
                     }
                     [linkedEmails addObject:submittedEmail.address];
                     
                     // Release pending email and refresh table to remove related cell
                     submittedEmail = nil;
                     [self.tableView reloadData];
                 } failure:^(NSError *error)
                  {
                      NSLog(@"[MXKAccountDetailsVC] Failed to link email: %@", error);
                      //Alert user TODO GFO
                      //                    [[AppDelegate theDelegate] showErrorAsAlert:error];
                      
                      // Release the pending email (even if it is Authenticated)
                      submittedEmail = nil;
                      [self.tableView reloadData];
                  }];
             }
             else
             {
                 NSLog(@"[MXKAccountDetailsVC] Failed to link email");
                 MXKAlert *alert = [[MXKAlert alloc] initWithTitle:nil message:@"Failed to link email"  style:MXKAlertStyleAlert];
                 [alertsArray addObject:alert];
                 alert.cancelButtonIndex = [alert addActionWithTitle:@"OK" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                                            {
                                                [alertsArray removeObject:alert];
                                            }];
                 [alert showInViewController:self];
                 // Reset wrong token
                 emailTokenCell.mxkTextField.text = nil;
             }
         } failure:^(NSError *error)
         {
             NSLog(@"[MXKAccountDetailsVC] Failed to submit email token: %@", error);
             //Alert user TODO GFO
             //            [[AppDelegate theDelegate] showErrorAsAlert:error];
             emailTokenCell.mxkButton.enabled = YES;
         }];
    }
    else if (sender == apnsNotificationsSwitch)
    {
        _mxAccount.enablePushNotifications = apnsNotificationsSwitch.on;
        apnsNotificationsSwitch.enabled = NO;
    }
    else if (sender == inAppNotificationsSwitch)
    {
        _mxAccount.enableInAppNotifications = inAppNotificationsSwitch.on;
        [self.tableView reloadData];
    }
}

#pragma mark - keyboard

- (void)dismissKeyboard
{
    if ([userDisplayName isFirstResponder])
    {
        // Hide the keyboard
        [userDisplayName resignFirstResponder];
        [self updateSaveUserInfoButtonStatus];
    }
    else if ([submittedEmailCell.mxkTextField isFirstResponder])
    {
        [submittedEmailCell.mxkTextField resignFirstResponder];
    }
    else if ([emailTokenCell.mxkTextField isFirstResponder])
    {
        [emailTokenCell.mxkTextField resignFirstResponder];
    }
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    // "Done" key has been pressed
    [self dismissKeyboard];
    return YES;
}

- (IBAction)textFieldEditingChanged:(id)sender
{
    if (sender == userDisplayName)
    {
        [self updateSaveUserInfoButtonStatus];
    }
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    
    linkedEmailsSection = notificationsSection = configurationSection = -1;
    
    if (!_mxAccount.disabled)
    {
        linkedEmailsSection = count ++;
        notificationsSection = count ++;
    }
    
    configurationSection = count ++;
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    if (section == linkedEmailsSection)
    {
        submittedEmailRowIndex = emailTokenRowIndex = -1;
        
        count = linkedEmails.count;
        submittedEmailRowIndex = count++;
        if (submittedEmail && submittedEmail.validationState >= MXK3PIDAuthStateTokenReceived)
        {
            emailTokenRowIndex = count++;
        }
        else
        {
            emailTokenCell = nil;
        }
    }
    else if (section == notificationsSection)
    {
        enableInAppNotifRowIndex = enablePushNotifRowIndex = userInfoNotifRowIndex = -1;
        
        if ([MXKAccountManager sharedManager].isAPNSAvailable) {
            enablePushNotifRowIndex = count++;
        }
        enableInAppNotifRowIndex = count++;
        userInfoNotifRowIndex = count++;
    }
    else if (section == configurationSection)
    {
        count = 2;
    }
    
    return count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == linkedEmailsSection)
    {
        if (indexPath.row == emailTokenRowIndex)
        {
            return 70;
        }
    }
    else if (indexPath.section == notificationsSection)
    {
        if (indexPath.row == userInfoNotifRowIndex)
        {
            UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, MAXFLOAT)];
            textView.font = [UIFont systemFontOfSize:14];
            textView.text = kUserInfoNotificationRulesText;
            CGSize contentSize = [textView sizeThatFits:textView.frame.size];
            return contentSize.height + 1;
        }
    }
    else if (indexPath.section == configurationSection)
    {
        if (indexPath.row == 0)
        {
            UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, MAXFLOAT)];
            textView.font = [UIFont systemFontOfSize:14];
            textView.text = [NSString stringWithFormat:kMXKAccountDetailsConfigurationFormatText, _mxAccount.mxCredentials.homeServer, _mxAccount.identityServerURL, _mxAccount.mxCredentials.userId];
            CGSize contentSize = [textView sizeThatFits:textView.frame.size];
            return contentSize.height + 1;
        }
    }
    
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (indexPath.section == linkedEmailsSection)
    {
        if (indexPath.row < linkedEmails.count)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsLinkedEmailCellId];
            if (!cell)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsLinkedEmailCellId];
            }
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = [linkedEmails objectAtIndex:indexPath.row];
        }
        else if (indexPath.row == submittedEmailRowIndex)
        {
            // Report the current email value (if any)
            NSString *currentEmail = nil;
            if (submittedEmailCell)
            {
                currentEmail = submittedEmailCell.mxkTextField.text;
            }
            
            submittedEmailCell = [[MXKTableViewCellWithTextFieldAndButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsSubmittedEmailCellId];
            if (!submittedEmailCell)
            {
                submittedEmailCell = [[MXKTableViewCellWithTextFieldAndButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsSubmittedEmailCellId];
            }
            
            submittedEmailCell.mxkTextField.text = currentEmail;
            submittedEmailCell.mxkButton.enabled = (currentEmail.length != 0);
            [submittedEmailCell.mxkButton setTitle:@"Link Email" forState:UIControlStateNormal];
            [submittedEmailCell.mxkButton setTitle:@"Link Email" forState:UIControlStateHighlighted];
            [submittedEmailCell.mxkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            if (emailTokenRowIndex != -1)
            {
                // Hide the separator
                CGSize screenSize = [[UIScreen mainScreen] bounds].size;
                CGFloat rightInset = (screenSize.width < screenSize.height) ? screenSize.height : screenSize.width;
                submittedEmailCell.separatorInset = UIEdgeInsetsMake(0.f, 0.f, 0.f, rightInset);
            }
            cell = submittedEmailCell;
        }
        else if (indexPath.row == emailTokenRowIndex)
        {
            // Report the current token value (if any)
            NSString *currentToken = nil;
            if (emailTokenCell)
            {
                currentToken = emailTokenCell.mxkTextField.text;
            }
            
            emailTokenCell = [[MXKTableViewCellWithLabelTextFieldAndButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsEmailTokenCellId];
            if (!emailTokenCell)
            {
                emailTokenCell = [[MXKTableViewCellWithLabelTextFieldAndButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsEmailTokenCellId];
            }
            
            emailTokenCell.mxkLabel.text = [NSString stringWithFormat:@"Enter validation token for %@:", submittedEmail.address];
            emailTokenCell.mxkTextField.text = currentToken;
            emailTokenCell.mxkButton.enabled = (currentToken.length != 0);
            [emailTokenCell.mxkButton setTitle:@"Submit code" forState:UIControlStateNormal];
            [emailTokenCell.mxkButton setTitle:@"Submit code" forState:UIControlStateHighlighted];
            [emailTokenCell.mxkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = emailTokenCell;
        }
    }
    else if (indexPath.section == notificationsSection)
    {
        if (indexPath.row == userInfoNotifRowIndex)
        {
            MXKTableViewCellWithTextView *userInfoCell = [[MXKTableViewCellWithTextView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithTextViewId];
            if (!userInfoCell)
            {
                userInfoCell = [[MXKTableViewCellWithTextView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithTextViewId];
            }
            
            userInfoCell.mxkTextView.text = kUserInfoNotificationRulesText;
            cell = userInfoCell;
        }
        else
        {
            MXKTableViewCellWithLabelAndSwitch *notificationsCell = [[MXKTableViewCellWithLabelAndSwitch alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithSwitchId];
            if (!notificationsCell)
            {
                notificationsCell = [[MXKTableViewCellWithLabelAndSwitch alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithSwitchId];
            }
            
            [notificationsCell.mxkSwitch addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventValueChanged];
            
            if (indexPath.row == enableInAppNotifRowIndex)
            {
                notificationsCell.mxkLabel.text = @"Enable In-App notifications";
                notificationsCell.mxkSwitch.on = _mxAccount.enableInAppNotifications;
                inAppNotificationsSwitch = notificationsCell.mxkSwitch;
            }
            else /* enablePushNotifRowIndex */
            {
                notificationsCell.mxkLabel.text = @"Enable push notifications";
                notificationsCell.mxkSwitch.on = _mxAccount.pushNotificationServiceIsActive;
                notificationsCell.mxkSwitch.enabled = YES;
                apnsNotificationsSwitch = notificationsCell.mxkSwitch;
            }
            
            cell = notificationsCell;
        }
    }
    else if (indexPath.section == configurationSection)
    {
        
        if (indexPath.row == 0)
        {
            MXKTableViewCellWithTextView *configCell = [[MXKTableViewCellWithTextView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithTextViewId];
            if (!configCell)
            {
                configCell = [[MXKTableViewCellWithTextView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithTextViewId];
            }
            
            configCell.mxkTextView.text = [NSString stringWithFormat:kMXKAccountDetailsConfigurationFormatText, _mxAccount.mxCredentials.homeServer, _mxAccount.identityServerURL, _mxAccount.mxCredentials.userId];
            cell = configCell;
        }
        else
        {
            logoutBtnCell = [[MXKTableViewCellWithButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithButtonId];
            if (!logoutBtnCell)
            {
                logoutBtnCell = [[MXKTableViewCellWithButton alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsCellWithButtonId];
            }
            [logoutBtnCell.mxkButton setTitle:@"Logout" forState:UIControlStateNormal];
            [logoutBtnCell.mxkButton setTitle:@"Logout" forState:UIControlStateHighlighted];
            [logoutBtnCell.mxkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            cell = logoutBtnCell;
        }
        
    }
    return cell;
}

#pragma mark - UITableView delegate

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30;
}
- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *sectionHeader = [[UIView alloc] initWithFrame:[tableView rectForHeaderInSection:section]];
    sectionHeader.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    UILabel *sectionLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, sectionHeader.frame.size.width - 10, sectionHeader.frame.size.height - 10)];
    sectionLabel.font = [UIFont boldSystemFontOfSize:16];
    sectionLabel.backgroundColor = [UIColor clearColor];
    [sectionHeader addSubview:sectionLabel];
    
    if (section == linkedEmailsSection)
    {
        sectionLabel.text = @"Linked emails";
    }
    else if (section == notificationsSection)
    {
        sectionLabel.text = @"Notifications";
    }
    else if (section == configurationSection)
    {
        sectionLabel.text = @"Configuration";
    }
    
    return sectionHeader;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == aTableView)
    {
        [aTableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

# pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *selectedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    if (selectedImage)
    {
        [self updateUserPictureButton:selectedImage];
        isAvatarUpdated = YES;
        saveUserInfoButton.enabled = YES;
    }
    [self dismissMediaPicker];
}

@end
