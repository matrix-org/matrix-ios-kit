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

#import "MXKTableViewCellWithButton.h"
#import "MXKTableViewCellWithTextFieldAndButton.h"
#import "MXKTableViewCellWithLabelTextFieldAndButton.h"
#import "MXKTableViewCellWithTextView.h"
#import "MXKTableViewCellWithLabelAndSwitch.h"

#import "NSBundle+MatrixKit.h"

#import "MXKConstants.h"

NSString* const kMXKAccountDetailsLinkedEmailCellId = @"kMXKAccountDetailsLinkedEmailCellId";

@interface MXKAccountDetailsViewController ()
{
    NSMutableArray *alertsArray;
    
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

    // Dynamic rows in the Linked emails section
    NSInteger submittedEmailRowIndex;
    
    // Notifications
    // Dynamic rows in the Notifications section
    NSInteger enablePushNotifRowIndex;
    NSInteger enableInAppNotifRowIndex;
    
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
    
    [saveUserInfoButton setTitle:[NSBundle mxk_localizedStringForKey:@"account_save_changes"] forState:UIControlStateNormal];
    [saveUserInfoButton setTitle:[NSBundle mxk_localizedStringForKey:@"account_save_changes"] forState:UIControlStateHighlighted];
    
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

        // Load linked emails
        [self loadLinkedEmails];

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
            MXKAlert *alert = [[MXKAlert alloc] initWithTitle:nil message:[NSBundle mxk_localizedStringForKey:@"message_unsaved_changes"] style:MXKAlertStyleAlert];
            [alertsArray addObject:alert];
            alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"discard"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
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
            [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"save"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
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
    
    submittedEmail = nil;
    emailSubmitButton = nil;
    emailTextField = nil;
    
    [self removeMatrixSession:self.mainSession];
    
    logoutButton = nil;
    
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
            
        } failure:^(NSError *error) {
             
             NSLog(@"[MXKAccountDetailsVC] Failed to set displayName: %@", error);
             __strong __typeof(weakSelf)strongSelf = weakSelf;
             
             // Alert user
             NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
             if (!title)
             {
                 title = [NSBundle mxk_localizedStringForKey:@"account_error_display_name_change_failed"];
             }
             NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
             
             MXKAlert *alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
             [strongSelf->alertsArray addObject:alert];
             alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"abort"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                                        {
                                            [strongSelf->alertsArray removeObject:alert];
                                            // Discard changes
                                            strongSelf.userDisplayName.text = strongSelf->currentDisplayName;
                                            [strongSelf updateUserPicture:strongSelf.mxAccount.userAvatarUrl force:YES];
                                            // Loop to end saving
                                            [strongSelf saveUserInfo];
                                        }];
             [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"retry"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
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
            [uploader uploadData:UIImageJPEGRepresentation(updatedPicture, 0.5) filename:nil mimeType:@"image/jpeg" success:^(NSString *url)
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
        title = [NSBundle mxk_localizedStringForKey:@"account_error_picture_change_failed"];
    }
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    
    MXKAlert *alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
    [alertsArray addObject:alert];
    alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"abort"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                               {
                                   [alertsArray removeObject:alert];
                                   // Remove change
                                   self.userDisplayName.text = currentDisplayName;
                                   [self updateUserPicture:_mxAccount.userAvatarUrl force:YES];
                                   // Loop to end saving
                                   [self saveUserInfo];
                               }];
    [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"retry"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
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
            
            NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:currentPictureThumbURL andType:nil inFolder:kMXKMediaManagerAvatarThumbnailFolder];
            
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

- (void)showValidationEmailDialogWithMessage:(NSString*)message
{
    MXKAlert *alert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"account_email_validation_title"]
                                              message:message
                                                style:MXKAlertStyleAlert];
    [alertsArray addObject:alert];

    alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"abort"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert){

        [alertsArray removeObject:alert];

        emailSubmitButton.enabled = YES;

    }];

    [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"continue"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

        [alertsArray removeObject:alert];

        __weak typeof(self) weakSelf = self;

        // We always bind emails when registering, so let's do the same here
        [submittedEmail add3PIDToUser:YES success:^{

            __strong __typeof(weakSelf)strongSelf = weakSelf;

            // Release pending email and refresh table to remove related cell
            strongSelf->emailTextField.text = nil;
            strongSelf->submittedEmail = nil;

            // Update linked emails
            [strongSelf loadLinkedEmails];

        } failure:^(NSError *error) {

            __strong __typeof(weakSelf)strongSelf = weakSelf;

            NSLog(@"[MXKAccountDetailsVC] Failed to bind email: %@", error);

            // Display the same popup again if the error is M_THREEPID_AUTH_FAILED
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringThreePIDAuthFailed])
            {
                [strongSelf showValidationEmailDialogWithMessage:[NSBundle mxk_localizedStringForKey:@"account_email_validation_error"]];
            }
            else
            {
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
            }

            // Release the pending email (even if it is Authenticated)
            [strongSelf.tableView reloadData];

        }];
    }];

    [alert showInViewController:self];
}

- (void)loadLinkedEmails
{
    // Refresh the account 3PIDs list
    [_mxAccount load3PIDs:^{

        [self.tableView reloadData];

    } failure:^(NSError *error) {
        // Display the data that has been loaded last time
        [self.tableView reloadData];
    }];
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
    else if (sender == logoutButton)
    {
        [[MXKAccountManager sharedManager] removeAccount:_mxAccount];
        self.mxAccount = nil;
    }
    else if (sender == emailSubmitButton)
    {
        // Email check
        if (![MXTools isEmailAddress:emailTextField.text])
        {
            MXKAlert *alert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"account_error_email_wrong_title"] message:[NSBundle mxk_localizedStringForKey:@"account_error_email_wrong_description"] style:MXKAlertStyleAlert];
            [alertsArray addObject:alert];

            alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                [alertsArray removeObject:alert];
            }];
            [alert showInViewController:self];

            return;
        }
        
        if (!submittedEmail || ![submittedEmail.address isEqualToString:emailTextField.text])
        {
            submittedEmail = [[MXK3PID alloc] initWithMedium:kMX3PIDMediumEmail andAddress:emailTextField.text];
        }
        
        emailSubmitButton.enabled = NO;

        [submittedEmail requestValidationTokenWithMatrixRestClient:self.mainSession.matrixRestClient success:^{

            [self showValidationEmailDialogWithMessage:[NSBundle mxk_localizedStringForKey:@"account_email_validation_message"]];

        } failure:^(NSError *error) {

            NSLog(@"[MXKAccountDetailsVC] Failed to request email token: %@", error);

            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];

            emailSubmitButton.enabled = YES;

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
    else if ([emailTextField isFirstResponder])
    {
        [emailTextField resignFirstResponder];
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
        count = _mxAccount.linkedEmails.count;
        submittedEmailRowIndex = count++;
    }
    else if (section == notificationsSection)
    {
        enableInAppNotifRowIndex = enablePushNotifRowIndex = -1;
        
        if ([MXKAccountManager sharedManager].isAPNSAvailable) {
            enablePushNotifRowIndex = count++;
        }
        enableInAppNotifRowIndex = count++;
    }
    else if (section == configurationSection)
    {
        count = 2;
    }
    
    return count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == configurationSection)
    {
        if (indexPath.row == 0)
        {
            UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, MAXFLOAT)];
            textView.font = [UIFont systemFontOfSize:14];
            
            NSString *configFormat = [NSString stringWithFormat:@"%@\n%@\n%@", [NSBundle mxk_localizedStringForKey:@"settings_config_home_server"], [NSBundle mxk_localizedStringForKey:@"settings_config_identity_server"], [NSBundle mxk_localizedStringForKey:@"settings_config_user_id"]];
            
            textView.text = [NSString stringWithFormat:configFormat, _mxAccount.mxCredentials.homeServer, _mxAccount.identityServerURL, _mxAccount.mxCredentials.userId];
            
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
        if (indexPath.row < _mxAccount.linkedEmails.count)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsLinkedEmailCellId];
            if (!cell)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMXKAccountDetailsLinkedEmailCellId];
            }
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = [_mxAccount.linkedEmails objectAtIndex:indexPath.row];
        }
        else if (indexPath.row == submittedEmailRowIndex)
        {
            // Report the current email value (if any)
            NSString *currentEmail = nil;
            if (emailTextField)
            {
                currentEmail = emailTextField.text;
            }
            
            MXKTableViewCellWithTextFieldAndButton *submittedEmailCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithTextFieldAndButton defaultReuseIdentifier]];
            if (!submittedEmailCell)
            {
                submittedEmailCell = [[MXKTableViewCellWithTextFieldAndButton alloc] init];
            }
            
            submittedEmailCell.mxkTextField.text = currentEmail;
            submittedEmailCell.mxkTextField.keyboardType = UIKeyboardTypeEmailAddress;
            submittedEmailCell.mxkButton.enabled = (currentEmail.length != 0);
            [submittedEmailCell.mxkButton setTitle:[NSBundle mxk_localizedStringForKey:@"account_link_email"] forState:UIControlStateNormal];
            [submittedEmailCell.mxkButton setTitle:[NSBundle mxk_localizedStringForKey:@"account_link_email"] forState:UIControlStateHighlighted];
            [submittedEmailCell.mxkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            emailSubmitButton = submittedEmailCell.mxkButton;
            emailTextField = submittedEmailCell.mxkTextField;

            cell = submittedEmailCell;
        }
    }
    else if (indexPath.section == notificationsSection)
    {
        MXKTableViewCellWithLabelAndSwitch *notificationsCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier]];
        if (!notificationsCell)
        {
            notificationsCell = [[MXKTableViewCellWithLabelAndSwitch alloc] init];
        }
        
        [notificationsCell.mxkSwitch addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventValueChanged];
        
        if (indexPath.row == enableInAppNotifRowIndex)
        {
            notificationsCell.mxkLabel.text = [NSBundle mxk_localizedStringForKey:@"settings_enable_inapp_notifications"];
            notificationsCell.mxkSwitch.on = _mxAccount.enableInAppNotifications;
            inAppNotificationsSwitch = notificationsCell.mxkSwitch;
        }
        else /* enablePushNotifRowIndex */
        {
            notificationsCell.mxkLabel.text = [NSBundle mxk_localizedStringForKey:@"settings_enable_push_notifications"];
            notificationsCell.mxkSwitch.on = _mxAccount.pushNotificationServiceIsActive;
            notificationsCell.mxkSwitch.enabled = YES;
            apnsNotificationsSwitch = notificationsCell.mxkSwitch;
        }
        
        cell = notificationsCell;
    }
    else if (indexPath.section == configurationSection)
    {
        if (indexPath.row == 0)
        {
            MXKTableViewCellWithTextView *configCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier]];
            if (!configCell)
            {
                configCell = [[MXKTableViewCellWithTextView alloc] init];
            }
            
            NSString *configFormat = [NSString stringWithFormat:@"%@\n%@\n%@", [NSBundle mxk_localizedStringForKey:@"settings_config_home_server"], [NSBundle mxk_localizedStringForKey:@"settings_config_identity_server"], [NSBundle mxk_localizedStringForKey:@"settings_config_user_id"]];
            
            configCell.mxkTextView.text = [NSString stringWithFormat:configFormat, _mxAccount.mxCredentials.homeServer, _mxAccount.identityServerURL, _mxAccount.mxCredentials.userId];
            
            cell = configCell;
        }
        else
        {
            MXKTableViewCellWithButton *logoutBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!logoutBtnCell)
            {
                logoutBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            [logoutBtnCell.mxkButton setTitle:[NSBundle mxk_localizedStringForKey:@"action_logout"] forState:UIControlStateNormal];
            [logoutBtnCell.mxkButton setTitle:[NSBundle mxk_localizedStringForKey:@"action_logout"] forState:UIControlStateHighlighted];
            [logoutBtnCell.mxkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            logoutButton = logoutBtnCell.mxkButton;
            
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
        sectionLabel.text = [NSBundle mxk_localizedStringForKey:@"account_linked_emails"];
    }
    else if (section == notificationsSection)
    {
        sectionLabel.text = [NSBundle mxk_localizedStringForKey:@"settings_title_notifications"];
    }
    else if (section == configurationSection)
    {
        sectionLabel.text = [NSBundle mxk_localizedStringForKey:@"settings_title_config"];
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
