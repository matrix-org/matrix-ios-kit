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

#import "MXKAuthenticationViewController.h"

#import "MXKAuthInputsEmailCodeBasedView.h"
#import "MXKAuthInputsPasswordBasedView.h"

#import "MXKAlert.h"

#import "MXKAccountManager.h"

#import "NSBundle+MatrixKit.h"

NSString *const MXKAuthErrorDomain = @"MXKAuthErrorDomain";

@interface MXKAuthenticationViewController ()
{
    /**
     The matrix REST client used to make matrix API requests.
     */
    MXRestClient *mxRestClient;
    
    /**
     Current request in progress.
     */
    MXHTTPOperation *mxCurrentOperation;
    
    /**
     Array of flows supported by the home server and implemented by the view controller (for the current auth type).
     */
    NSMutableArray *supportedFlows;
    
    /**
     The current view in which auth inputs are displayed (`MXKAuthInputsView-inherited` instance).
     */
    MXKAuthInputsView *currentAuthInputsView;
    
    /**
     Reference to any opened alert view.
     */
    MXKAlert *alert;
}

@end

@implementation MXKAuthenticationViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKAuthenticationViewController class])
                          bundle:[NSBundle bundleForClass:[MXKAuthenticationViewController class]]];
}

+ (instancetype)authenticationViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKAuthenticationViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKAuthenticationViewController class]]];
}


#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Check whether the view controller has been pushed via storyboard
    if (!_authenticationScrollView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // Load welcome image from MatrixKit asset bundle
    self.welcomeImageView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"logoHighRes"];
    
    // Adjust bottom constraint of the scroll view in order to take into account potential tabBar
    if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)])
    {
        [NSLayoutConstraint deactivateConstraints:@[_authScrollViewBottomConstraint]];
    }
    else
    {
        [self.view removeConstraint:_authScrollViewBottomConstraint];
    }
    
    _authScrollViewBottomConstraint = [NSLayoutConstraint constraintWithItem:self.bottomLayoutGuide
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.authenticationScrollView
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0f
                                                                    constant:0.0f];
    if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
    {
        [NSLayoutConstraint activateConstraints:@[_authScrollViewBottomConstraint]];
    }
    else
    {
        [self.view addConstraint:_authScrollViewBottomConstraint];
    }
    
    // Force contentView in full width
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                      attribute:NSLayoutAttributeLeading
                                                                      relatedBy:0
                                                                         toItem:self.view
                                                                      attribute:NSLayoutAttributeLeft
                                                                     multiplier:1.0
                                                                       constant:0];
    [self.view addConstraint:leftConstraint];
    
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                       attribute:NSLayoutAttributeTrailing
                                                                       relatedBy:0
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeRight
                                                                      multiplier:1.0
                                                                        constant:0];
    [self.view addConstraint:rightConstraint];
    
    [self.view setNeedsUpdateConstraints];
    
    _authenticationScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _submitButton.enabled = NO;
    _authSwitchButton.enabled = YES;
    supportedFlows = [NSMutableArray array];
    
    _homeServerTextField.text = _defaultHomeServerUrl;
    _identityServerTextField.text = _defaultIdentityServerUrl;
    
    // Create here REST client
    if (_homeServerTextField.text.length)
    {
        mxRestClient = [[MXRestClient alloc] initWithHomeServer:_homeServerTextField.text];
        if (_identityServerTextField.text.length)
        {
            [mxRestClient setIdentityServer:_identityServerTextField.text];
        }
    }
    
    // Set initial auth type
    _authType = MXKAuthenticationTypeLogin;
}

- (void)dealloc
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Update supported authentication flow
    self.authType = _authType;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTextFieldChange:) name:UITextFieldTextDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self dismissKeyboard];
    
    // close any opened alert
    if (alert)
    {
        [alert dismiss:NO];
        alert = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
}

#pragma mark - Override MXKViewController

- (void)onKeyboardShowAnimationComplete
{
    // Report the keyboard view in order to track keyboard frame changes
    // TODO define inputAccessoryView for each text input
    // and report the inputAccessoryView.superview of the firstResponder in self.keyboardView.
}

- (void)setKeyboardHeight:(CGFloat)keyboardHeight
{
    // Deduce the bottom inset for the scroll view (Don't forget the potential tabBar)
    CGFloat scrollViewInsetBottom = keyboardHeight - self.bottomLayoutGuide.length;
    // Check whether the keyboard is over the tabBar
    if (scrollViewInsetBottom < 0)
    {
        scrollViewInsetBottom = 0;
    }
    
    UIEdgeInsets insets = self.authenticationScrollView.contentInset;
    insets.bottom = scrollViewInsetBottom;
    self.authenticationScrollView.contentInset = insets;
}

- (void)destroy
{
    supportedFlows = nil;
    if (mxCurrentOperation){
        [mxCurrentOperation cancel];
        mxCurrentOperation = nil;
    }
    
    [mxRestClient close];
    mxRestClient = nil;
    
    [super destroy];
}

#pragma mark -

+ (BOOL)isImplementedFlowType:(MXLoginFlowType)flowType forAuthType:(MXKAuthenticationType)authType
{
    if (authType == MXKAuthenticationTypeLogin)
    {
        if ([flowType isEqualToString:kMXLoginFlowTypePassword]
            /*|| [flowType isEqualToString:kMXLoginFlowTypeEmailCode]*/)
        {
            return YES;
        }
    }
    else
    { // AuthenticationTypeRegister
        // No registration flow is supported yet
    }
    
    return NO;
}

- (void)setAuthType:(MXKAuthenticationType)authType
{
    if (authType == MXKAuthenticationTypeLogin)
    {
        _createAccountLabel.hidden = YES;
        [_submitButton setTitle:@"Login" forState:UIControlStateNormal];
        [_submitButton setTitle:@"Login" forState:UIControlStateHighlighted];
        [_authSwitchButton setTitle:@"Create account" forState:UIControlStateNormal];
        [_authSwitchButton setTitle:@"Create account" forState:UIControlStateHighlighted];
    }
    else
    {
        _createAccountLabel.hidden = NO;
        [_submitButton setTitle:@"Sign up" forState:UIControlStateNormal];
        [_submitButton setTitle:@"Sign up" forState:UIControlStateHighlighted];
        [_authSwitchButton setTitle:@"Back" forState:UIControlStateNormal];
        [_authSwitchButton setTitle:@"Back" forState:UIControlStateHighlighted];
    }
    
    _authType = authType;
    
    // Update supported authentication flow
    [self refreshSupportedAuthFlow];
}

- (void)setSelectedFlow:(MXLoginFlow *)selectedFlow
{
    // Hide views which depend on auth flow
    _submitButton.hidden = YES;
    _noFlowLabel.hidden = YES;
    _retryButton.hidden = YES;
    
    [currentAuthInputsView removeFromSuperview];
    currentAuthInputsView.delegate = nil;
    currentAuthInputsView = nil;
    
    
    // Create the right auth inputs view
    if ([selectedFlow.type isEqualToString:kMXLoginFlowTypePassword])
    {
        currentAuthInputsView = [MXKAuthInputsPasswordBasedView authInputsView];
    }
    else if ([selectedFlow.type isEqualToString:kMXLoginFlowTypeEmailCode])
    {
        currentAuthInputsView = [MXKAuthInputsEmailCodeBasedView authInputsView];
    }
    
    if (currentAuthInputsView)
    {
        
        [_authInputsContainerView addSubview:currentAuthInputsView];
        
        currentAuthInputsView.delegate = self;
        _submitButton.hidden = NO;
        currentAuthInputsView.hidden = NO;
        currentAuthInputsView.authType = _authType;
        _authInputContainerViewHeightConstraint.constant = currentAuthInputsView.actualHeight;
        
        [_authInputsContainerView addConstraint:[NSLayoutConstraint constraintWithItem:_authInputsContainerView
                                                                             attribute:NSLayoutAttributeTop
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:currentAuthInputsView
                                                                             attribute:NSLayoutAttributeTop
                                                                            multiplier:1.0f
                                                                              constant:0.0f]];
        [_authInputsContainerView addConstraint:[NSLayoutConstraint constraintWithItem:_authInputsContainerView
                                                                             attribute:NSLayoutAttributeLeading
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:currentAuthInputsView
                                                                             attribute:NSLayoutAttributeLeading
                                                                            multiplier:1.0f
                                                                              constant:0.0f]];
        [_authInputsContainerView addConstraint:[NSLayoutConstraint constraintWithItem:_authInputsContainerView
                                                                             attribute:NSLayoutAttributeTrailing
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:currentAuthInputsView
                                                                             attribute:NSLayoutAttributeTrailing
                                                                            multiplier:1.0f
                                                                              constant:0.0f]];
    }
    else
    {
        // No input fields are displayed
        _authInputContainerViewHeightConstraint.constant = 80;
    }
    
    [self.view layoutIfNeeded];
    
    // Refresh content view height
    _contentViewHeightConstraint.constant = _authSwitchButton.frame.origin.y + _authSwitchButton.frame.size.height + 15;
    
    _selectedFlow = selectedFlow;
}

- (void)setDefaultHomeServerUrl:(NSString *)defaultHomeServerUrl
{
    _defaultHomeServerUrl = defaultHomeServerUrl;
    
    if (!_homeServerTextField.text.length)
    {
        _homeServerTextField.text = _defaultHomeServerUrl;
        
        // Update UI
        [self textFieldDidEndEditing:_homeServerTextField];
    }
}

- (void)setDefaultIdentityServerUrl:(NSString *)defaultIdentityServerUrl
{
    _defaultIdentityServerUrl = defaultIdentityServerUrl;
    
    if (!_identityServerTextField.text.length)
    {
        _identityServerTextField.text = _defaultIdentityServerUrl;
        
        // Update UI
        [self textFieldDidEndEditing:_identityServerTextField];
    }
}

- (void)setUserInteractionEnabled:(BOOL)isEnabled
{
    _submitButton.enabled = (isEnabled && currentAuthInputsView.areAllRequiredFieldsFilled);
    _authSwitchButton.enabled = isEnabled;
    
    _homeServerTextField.enabled = isEnabled;
    _identityServerTextField.enabled = isEnabled;
}

- (void)refreshSupportedAuthFlow
{
    // Remove reachability observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
    
    // Cancel potential request in progress
    [mxCurrentOperation cancel];
    mxCurrentOperation = nil;
    
    if (mxRestClient)
    {
        [_authenticationActivityIndicator startAnimating];
        self.selectedFlow = nil;
        if (_authType == MXKAuthenticationTypeLogin)
        {
            mxCurrentOperation = [mxRestClient getLoginFlow:^(NSArray *flows) {
                                      [self handleHomeServerFlows:flows];
                                  } failure:^(NSError *error) {
                                      NSLog(@"[MXKAuthenticationVC] Failed to get Login flows: %@", error);
                                      [self onFailureDuringMXOperation:error];
                                  }];
        }
        else
        {
            //        mxCurrentOperation = [mxRestClient getRegisterFlow:^(NSArray *flows){
            //            [self handleHomeServerFlows:flows];
            //        } failure:^(NSError *error){
            //            NSLog(@"[MXKAuthenticationVC] Failed to get Register flows: %@", error);
            //            [self onFailureDuringMXOperation:error];
            //        }];
            
            // Currently no registration flow are supported, we switch directly to the fallback page
            [self showRegistrationFallBackView:[mxRestClient registerFallback]];
        }
    }
}

- (void)handleHomeServerFlows:(NSArray *)flows
{
    [_authenticationActivityIndicator stopAnimating];
    
    [supportedFlows removeAllObjects];
    for (MXLoginFlow* flow in flows)
    {
        if ([MXKAuthenticationViewController isImplementedFlowType:flow.type forAuthType:_authType])
        {
            // Check here all stages
            BOOL isSupported = YES;
            if (flow.stages.count)
            {
                for (NSString *stage in flow.stages)
                {
                    if ([MXKAuthenticationViewController isImplementedFlowType:stage forAuthType:_authType] == NO)
                    {
                        isSupported = NO;
                        break;
                    }
                }
            }
            
            if (isSupported)
            {
                [supportedFlows addObject:flow];
            }
        }
    }
    
    if (supportedFlows.count)
    {
        // FIXME display supported flows
        // Currently we select the first one
        self.selectedFlow = [supportedFlows firstObject];
    }
    
    if (!_selectedFlow)
    {
        // Notify user that no flow is supported
        if (_authType == MXKAuthenticationTypeLogin)
        {
            _noFlowLabel.text = @"Currently we do not support Login flows defined by this Home Server.";
        }
        else
        {
            _noFlowLabel.text = @"Registration is not currently supported.";
        }
        NSLog(@"[MXKAuthenticationVC] Warning: %@", _noFlowLabel.text);
        
        _noFlowLabel.hidden = NO;
        _retryButton.hidden = NO;
    }
}

- (void)onFailureDuringMXOperation:(NSError*)error
{
    mxCurrentOperation = nil;
    
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == kCFURLErrorCancelled)
    {
        // Ignore this error
        return;
    }
    
    [_authenticationActivityIndicator stopAnimating];
    
    // Alert user
    NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
    if (!title)
        
    {
        title = @"Error";
    }
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    
    alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
    alert.cancelButtonIndex = [alert addActionWithTitle:@"Dismiss" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                               {}];
    [alert showInViewController:self];
    
    // Display failure reason
    _noFlowLabel.hidden = NO;
    _noFlowLabel.text = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    if (!_noFlowLabel.text.length)
    {
        _noFlowLabel.text = @"We failed to retrieve authentication information from this Home Server";
    }
    _retryButton.hidden = NO;
    
    // Handle specific error code here
    if ([error.domain isEqualToString:NSURLErrorDomain])
    {
        // Check network reachability
        if (error.code == NSURLErrorNotConnectedToInternet)
        {
            // Add reachability observer in order to launch a new request when network will be available
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onReachabilityStatusChange:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
        }
        else if (error.code == kCFURLErrorTimedOut)
        {
            // Send a new request in 2 sec
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self refreshSupportedAuthFlow];
            });
        }
    }
}

- (void)onReachabilityStatusChange:(NSNotification *)notif
{
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    AFNetworkReachabilityStatus status = reachabilityManager.networkReachabilityStatus;
    
    if (status == AFNetworkReachabilityStatusReachableViaWiFi || status == AFNetworkReachabilityStatusReachableViaWWAN)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshSupportedAuthFlow];
        });
    }
    else if (status == AFNetworkReachabilityStatusNotReachable)
    {
        _noFlowLabel.text = @"Please check your network connectivity";
    }
}

- (IBAction)onButtonPressed:(id)sender
{
    [self dismissKeyboard];
    
    if (sender == _submitButton)
    {
        if (mxRestClient)
        {
            // Disable user interaction to prevent multiple requests
            [self setUserInteractionEnabled:NO];
            [self.authInputsContainerView bringSubviewToFront: _authenticationActivityIndicator];
            [_authenticationActivityIndicator startAnimating];
            
            if (_authType == MXKAuthenticationTypeLogin)
            {
                if ([_selectedFlow.type isEqualToString:kMXLoginFlowTypePassword])
                {
                    MXKAuthInputsPasswordBasedView *authInputsView = (MXKAuthInputsPasswordBasedView*)currentAuthInputsView;
                    
                    [mxRestClient loginWithUser:authInputsView.userLoginTextField.text andPassword:authInputsView.passWordTextField.text
                                        success:^(MXCredentials *credentials){
                                            [_authenticationActivityIndicator stopAnimating];
                                            
                                            // Sanity check: check whether the user is not already logged in with this id
                                            if ([[MXKAccountManager sharedManager] accountForUserId:credentials.userId])
                                            {
                                                //Alert user
                                                __weak typeof(self) weakSelf = self;
                                                alert = [[MXKAlert alloc] initWithTitle:@"Already logged in" message:nil style:MXKAlertStyleAlert];
                                                [alert addActionWithTitle:@"OK" style:MXKAlertActionStyleCancel handler:^(MXKAlert *alert) {
                                                    // We remove the authentication view controller.
                                                    [weakSelf withdrawViewControllerAnimated:YES completion:nil];
                                                }];
                                                [alert showInViewController:self];
                                            }
                                            else
                                            {
                                                // Report the new account in account manager
                                                MXKAccount *account = [[MXKAccount alloc] initWithCredentials:credentials];
                                                account.identityServerURL = _identityServerTextField.text;
                                                
                                                [[MXKAccountManager sharedManager] addAccount:account];
                                                
                                                if (_delegate)
                                                {
                                                    [_delegate authenticationViewController:self didLogWithUserId:credentials.userId];
                                                }
                                            }
                                        }
                                        failure:^(NSError *error){
                                            [self onFailureDuringAuthRequest:error];
                                        }];
                }
                else
                {
                    // FIXME
                    [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{@"error": @"Not supported yet"}]];
                }
            }
            else
            {
                // FIXME
                [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{@"error": @"Not supported yet"}]];
            }
        }
    }
    else if (sender == _authSwitchButton){
        if (_authType == MXKAuthenticationTypeLogin)
        {
            self.authType = MXKAuthenticationTypeRegister;
        }
        else
        {
            self.authType = MXKAuthenticationTypeLogin;
        }
    }
    else if (sender == _retryButton)
    {
        [self refreshSupportedAuthFlow];
    }
    else if (sender == _cancelRegistrationFallbackButton)
    {
        // Hide fallback webview
        [self hideRegistrationFallbackView];
        self.authType = MXKAuthenticationTypeLogin;
    }
}

- (void)onFailureDuringAuthRequest:(NSError *)error
{
    [_authenticationActivityIndicator stopAnimating];
    [self setUserInteractionEnabled:YES];
    
    NSLog(@"[MXKAuthenticationVC] Auth request failed: %@", error);
    
    // translate the error code to a human message
    NSString* message = error.localizedDescription;
    NSDictionary* dict = error.userInfo;
    
    // detect if it is a Matrix SDK issue
    if (dict)
    {
        NSString* localizedError = [dict valueForKey:@"error"];
        NSString* errCode = [dict valueForKey:@"errcode"];
        
        if (errCode)
        {
            if ([errCode isEqualToString:@"M_FORBIDDEN"])
            {
                message = @"Invalid username/password";
            }
            else if ([errCode isEqualToString:@"M_UNKNOWN_TOKEN"])
            {
                message = @"The access token specified was not recognised";
            }
            else if ([errCode isEqualToString:@"M_BAD_JSON"])
            {
                message = @"Malformed JSON";
            }
            else if ([errCode isEqualToString:@"M_NOT_JSON"])
            {
                message = @"Did not contain valid JSON";
            }
            else if ([errCode isEqualToString:@"M_LIMIT_EXCEEDED"])
            {
                message = @"Too many requests have been sent";
            }
            else if ([errCode isEqualToString:@"M_USER_IN_USE"])
            {
                message = @"This user name is already used";
            }
            else if ([errCode isEqualToString:@"M_LOGIN_EMAIL_URL_NOT_YET"])
            {
                message = @"The email link which has not been clicked yet";
            }
            else
            {
                message = errCode;
            }
        }
        else if (localizedError.length > 0)
        {
            message = localizedError;
        }
    }
    
    //Alert user
    alert = [[MXKAlert alloc] initWithTitle:@"Login Failed" message:message style:MXKAlertStyleAlert];
    [alert addActionWithTitle:@"Dismiss" style:MXKAlertActionStyleCancel handler:^(MXKAlert *alert)
     {}];
    [alert showInViewController:self];
}

#pragma mark - Keyboard handling

- (void)dismissKeyboard
{
    // Hide the keyboard
    [currentAuthInputsView dismissKeyboard];
    [_homeServerTextField resignFirstResponder];
    [_identityServerTextField resignFirstResponder];
}

#pragma mark - UITextField delegate

- (void)onTextFieldChange:(NSNotification *)notif
{
    _submitButton.enabled = currentAuthInputsView.areAllRequiredFieldsFilled;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == _homeServerTextField)
    {
        if (!textField.text.length)
        {
            // Force refresh with default value
            textField.text = _defaultHomeServerUrl;
        }
        
        // Refresh REST client
        if (textField.text.length)
        {
            mxRestClient = [[MXRestClient alloc] initWithHomeServer:textField.text];
            if (_identityServerTextField.text.length)
            {
                [mxRestClient setIdentityServer:_identityServerTextField.text];
            }
        }
        else
        {
            [mxRestClient close];
            mxRestClient = nil;
        }
        
        // Refresh UI
        [self refreshSupportedAuthFlow];
    }
    else if (textField == _identityServerTextField)
    {
        if (!textField.text.length)
        {
            // Force refresh with default value
            textField.text = _defaultIdentityServerUrl;
        }
        
        // Update REST client
        if (mxRestClient)
        {
            [mxRestClient setIdentityServer:textField.text];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    if (textField.returnKeyType == UIReturnKeyDone)
    {
        // "Done" key has been pressed
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark - AuthInputsViewDelegate delegate

- (void)authInputsDoneKeyHasBeenPressed:(MXKAuthInputsView *)authInputsView
{
    if (_submitButton.isEnabled)
    {
        // Launch authentication now
        [self onButtonPressed:_submitButton];
    }
}

#pragma mark - Registration Fallback

- (void)showRegistrationFallBackView:(NSString*)fallbackPage
{
    _authenticationScrollView.hidden = YES;
    _registrationFallbackContentView.hidden = NO;
    
    [_registrationFallbackWebView openFallbackPage:fallbackPage success:^(MXCredentials *credentials) {
         
         // Workaround: HS does not return the right URL. Use the one we used to make the request
         credentials.homeServer = mxRestClient.homeserver;
         
         // Report the new account in accounts manager
         MXKAccount *account = [[MXKAccount alloc] initWithCredentials:credentials];
         account.identityServerURL = _identityServerTextField.text;
         
         [[MXKAccountManager sharedManager] addAccount:account];
         
         if (_delegate)
         {
             [_delegate authenticationViewController:self didLogWithUserId:credentials.userId];
         }
     }];
}

- (void)hideRegistrationFallbackView
{
    [_registrationFallbackWebView stopLoading];
    _authenticationScrollView.hidden = NO;
    _registrationFallbackContentView.hidden = YES;
}

@end
