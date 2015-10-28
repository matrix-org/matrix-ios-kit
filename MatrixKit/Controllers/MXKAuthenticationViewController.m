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
#import "NSData+MatrixKit.h"

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
     The current view in which auth inputs are displayed (`MXKAuthInputsView-inherited` instance).
     */
    MXKAuthInputsView *currentAuthInputsView;
    
    /**
     Reference to any opened alert view.
     */
    MXKAlert *alert;
    
    /**
     The mapping between flow type and MXKAuthInputsView classes used when logging in.
     */
    NSMutableDictionary *loginAuthInputsViewMap;
    
    /**
     The mapping between flow type and MXKAuthInputsView classes used when registering.
     */
    NSMutableDictionary *registerAuthInputsViewMap;
    
    /**
     Customized block used to handle unrecognized certificate (nil by default).
     */
    MXHTTPClientOnUnrecognizedCertificate onUnrecognizedCertificateCustomBlock;
    
    /**
     The current authentication fallback URL (if any).
     */
    NSString *authenticationFallback;
    
    /**
     The cancel button added in navigation bar when fallback page is opened.
     */
    UIBarButtonItem *cancelFallbackBarButton;
}

/**
 The current selected login flow
 */
@property (nonatomic) MXLoginFlow *selectedFlow;

@end

@implementation MXKAuthenticationViewController
@synthesize selectedFlow;

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
                                                                      attribute:NSLayoutAttributeLeading
                                                                     multiplier:1.0
                                                                       constant:0];
    [self.view addConstraint:leftConstraint];
    
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                       attribute:NSLayoutAttributeTrailing
                                                                       relatedBy:0
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeTrailing
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
    
    // Create here REST client (if homeserver is defined)
    [self updateRESTClient];
    
    // Localize labels
    _subTitleLabel.text = [NSBundle mxk_localizedStringForKey:@"login_create_account"];
    _homeServerLabel.text = [NSBundle mxk_localizedStringForKey:@"login_home_server_title"];
    _homeServerTextField.placeholder = [NSBundle mxk_localizedStringForKey:@"login_server_url_placeholder"];
    _homeServerInfoLabel.text = [NSBundle mxk_localizedStringForKey:@"login_home_server_info"];
    _identityServerLabel.text = [NSBundle mxk_localizedStringForKey:@"login_identity_server_title"];
    _identityServerTextField.placeholder = [NSBundle mxk_localizedStringForKey:@"login_server_url_placeholder"];
    _identityServerInfoLabel.text = [NSBundle mxk_localizedStringForKey:@"login_identity_server_info"];
    [_cancelAuthFallbackButton setTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
    [_cancelAuthFallbackButton setTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] forState:UIControlStateHighlighted];
    
    // Set initial auth type
    _authType = MXKAuthenticationTypeLogin;
    
    // Initialize supported flows by defining authInputs views
    loginAuthInputsViewMap = [NSMutableDictionary dictionary];
    loginAuthInputsViewMap[kMXLoginFlowTypePassword] = MXKAuthInputsPasswordBasedView.class;
//    loginAuthInputsViewMap[kMXLoginFlowTypeEmailCode] = MXKAuthInputsEmailCodeBasedView.class;
    
    registerAuthInputsViewMap = [NSMutableDictionary dictionary];
    // No registration flow is supported yet
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
    
    loginAuthInputsViewMap = nil;
    registerAuthInputsViewMap = nil;

    authenticationFallback = nil;
    cancelFallbackBarButton = nil;
    
    [super destroy];
}

#pragma mark - Class methods

- (void)registerAuthInputsViewClass:(Class)authInputsViewClass forFlowType:(MXLoginFlowType)flowType andAuthType:(MXKAuthenticationType)authType
{
    if (flowType)
    {
        // Sanity check: accept only MXKAuthInputsView classes or sub-classes
        NSParameterAssert([authInputsViewClass isSubclassOfClass:MXKAuthInputsView.class]);
        
        if (authType == MXKAuthenticationTypeLogin)
        {
            loginAuthInputsViewMap[flowType] = authInputsViewClass;
        }
        else
        {
            registerAuthInputsViewMap[flowType] = authInputsViewClass;
        }
    }
}

- (void)setAuthType:(MXKAuthenticationType)authType
{
    if (authType == MXKAuthenticationTypeLogin)
    {
        _subTitleLabel.hidden = YES;
        [_submitButton setTitle:[NSBundle mxk_localizedStringForKey:@"login"] forState:UIControlStateNormal];
        [_submitButton setTitle:[NSBundle mxk_localizedStringForKey:@"login"] forState:UIControlStateHighlighted];
        [_authSwitchButton setTitle:[NSBundle mxk_localizedStringForKey:@"create_account"] forState:UIControlStateNormal];
        [_authSwitchButton setTitle:[NSBundle mxk_localizedStringForKey:@"create_account"] forState:UIControlStateHighlighted];
    }
    else
    {
        _subTitleLabel.hidden = NO;
        [_submitButton setTitle:[NSBundle mxk_localizedStringForKey:@"sign_up"] forState:UIControlStateNormal];
        [_submitButton setTitle:[NSBundle mxk_localizedStringForKey:@"sign_up"] forState:UIControlStateHighlighted];
        [_authSwitchButton setTitle:[NSBundle mxk_localizedStringForKey:@"back"] forState:UIControlStateNormal];
        [_authSwitchButton setTitle:[NSBundle mxk_localizedStringForKey:@"back"] forState:UIControlStateHighlighted];
    }
    
    _authType = authType;
    
    // Update supported authentication flow
    [self refreshSupportedAuthFlow];
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

- (void)refreshSupportedAuthFlow
{
    // Remove reachability observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
    
    // Cancel potential request in progress
    [mxCurrentOperation cancel];
    mxCurrentOperation = nil;
    
    [_authenticationActivityIndicator stopAnimating];
    
    // Reset potential authentication fallback url
    authenticationFallback = nil;
    
    if (mxRestClient)
    {
        [_authenticationActivityIndicator startAnimating];
        self.selectedFlow = nil;
        if (_authType == MXKAuthenticationTypeLogin)
        {
            mxCurrentOperation = [mxRestClient getLoginFlow:^(NSDictionary *JSONResponse) {
                
                NSArray *flows = [MXLoginFlow modelsFromJSON:JSONResponse[@"flows"]];
                [self handleHomeServerFlows:flows];
                
            } failure:^(NSError *error) {
                
                NSLog(@"[MXKAuthenticationVC] Failed to get Login flows: %@", error);
                [self onFailureDuringMXOperation:error];
                
            }];
        }
        else
        {
            mxCurrentOperation = [mxRestClient getRegisterFlow:^(NSDictionary *JSONResponse){
                
                NSArray *flows = [MXLoginFlow modelsFromJSON:JSONResponse[@"flows"]];
                [self handleHomeServerFlows:flows];
                
            } failure:^(NSError *error){
                
                NSLog(@"[MXKAuthenticationVC] Failed to get Register flows: %@", error);
                [self onFailureDuringMXOperation:error];
                
            }];
        }
    }
}

- (void)setOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertificateBlock
{
    onUnrecognizedCertificateCustomBlock = onUnrecognizedCertificateBlock;
}

#pragma mark - Privates

- (void)updateRESTClient
{
    NSString *homeserverURL = _homeServerTextField.text;
    
    if (homeserverURL.length)
    {
        // Check change
        if ([homeserverURL isEqualToString:mxRestClient.homeserver] == NO)
        {
            mxRestClient = [[MXRestClient alloc] initWithHomeServer:homeserverURL andOnUnrecognizedCertificateBlock:^BOOL(NSData *certificate) {
                
                // Check first if the app developer provided its own certificate handler.
                if (onUnrecognizedCertificateCustomBlock)
                {
                    return onUnrecognizedCertificateCustomBlock (certificate);
                }
                
                // Else prompt the user by displaying a fingerprint (SHA256) of the certificate.
                __block BOOL isTrusted;
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                
                NSString *title = [NSBundle mxk_localizedStringForKey:@"ssl_could_not_verify"];
                NSString *homeserverURLStr = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"ssl_homeserver_url"], homeserverURL];
                NSString *fingerprint = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"ssl_fingerprint_hash"], @"SHA256"];
                NSString *certFingerprint = [certificate SHA256AsHexString];
                
                NSString *msg = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@", [NSBundle mxk_localizedStringForKey:@"ssl_cert_not_trust"], [NSBundle mxk_localizedStringForKey:@"ssl_cert_new_account_expl"], homeserverURLStr, fingerprint, certFingerprint, [NSBundle mxk_localizedStringForKey:@"ssl_only_accept"]];
                
                alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
                alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert){
                    
                    isTrusted = NO;
                    dispatch_semaphore_signal(semaphore);
                    
                }];
                [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ssl_trust"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert){
                    
                    isTrusted = YES;
                    dispatch_semaphore_signal(semaphore);
                    
                }];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alert showInViewController:self];
                });
                
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                if (!isTrusted)
                {
                    // Cancel request in progress
                    [mxCurrentOperation cancel];
                    mxCurrentOperation = nil;
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];

                    [_authenticationActivityIndicator stopAnimating];
                }
                
                return isTrusted;
            }];
            
            if (_identityServerTextField.text.length)
            {
                [mxRestClient setIdentityServer:_identityServerTextField.text];
            }
        }
    }
    else
    {
        [mxRestClient close];
        mxRestClient = nil;
    }
}

- (void)setUserInteractionEnabled:(BOOL)isEnabled
{
    _submitButton.enabled = (isEnabled && currentAuthInputsView.areAllRequiredFieldsFilled);
    _authSwitchButton.enabled = isEnabled;
    
    _homeServerTextField.enabled = isEnabled;
    _identityServerTextField.enabled = isEnabled;
}

- (BOOL)isImplementedFlowType:(MXLoginFlowType)flowType forAuthType:(MXKAuthenticationType)authType
{
    // Sanity check
    if (flowType)
    {
        NSDictionary *authInputsViewMap;
        
        if (authType == MXKAuthenticationTypeLogin)
        {
            authInputsViewMap = loginAuthInputsViewMap;
        }
        else
        {
            authInputsViewMap = registerAuthInputsViewMap;
        }
        
        // A flow is supported only if an authInputsView class is registered.
        return (authInputsViewMap[flowType] != nil);
    }
    
    return NO;
}

- (void)handleHomeServerFlows:(NSArray *)flows
{
    [_authenticationActivityIndicator stopAnimating];
    mxCurrentOperation = nil;
    
    // Check whether fallback is defined
    if (_authType == MXKAuthenticationTypeLogin)
    {
        authenticationFallback = [mxRestClient loginFallback];
    }
    else
    {
        authenticationFallback = [mxRestClient registerFallback];
    }
    
    // List supported flows
    [supportedFlows removeAllObjects];
    
    for (MXLoginFlow* flow in flows)
    {
        // Check whether flow type is defined (this type has been deprecated since C-S API v2)
        if (flow.type)
        {
            if ([self isImplementedFlowType:flow.type forAuthType:_authType])
            {
                // Check here all stages
                BOOL isSupported = YES;
                if (flow.stages.count)
                {
                    for (NSString *stage in flow.stages)
                    {
                        if ([self isImplementedFlowType:stage forAuthType:_authType] == NO)
                        {
                            NSLog(@"[MXKAuthenticationVC] %@: %@ stage is not supported.", (_authType == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
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
            else
            {
                NSLog(@"[MXKAuthenticationVC] %@: %@ stage is not supported.", (_authType == MXKAuthenticationTypeLogin ? @"login" : @"register"), flow.type);
            }
        }
        else
        {
            // Check here all stages
            BOOL isSupported = YES;
            if (flow.stages.count)
            {
                for (NSString *stage in flow.stages)
                {
                    if ([self isImplementedFlowType:stage forAuthType:_authType] == NO)
                    {
                        NSLog(@"[MXKAuthenticationVC] %@: %@ stage is not supported.", (_authType == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
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
    
    // We will suggest using the fallback page (if any), when at least one flow is not supported.
    if ((supportedFlows.count != flows.count) && authenticationFallback.length)
    {
        NSLog(@"[MXKAuthenticationVC] Suggest using fallback page");
    }
    else
    {
        if (supportedFlows.count)
        {
            // FIXME display supported flows
            // Currently we select the first one
            self.selectedFlow = [supportedFlows firstObject];
        }
    }
    
    if (!self.selectedFlow)
    {
        // Notify user that no flow is supported
        if (_authType == MXKAuthenticationTypeLogin)
        {
            _noFlowLabel.text = [NSBundle mxk_localizedStringForKey:@"login_error_do_not_support_login_flows"];
        }
        else
        {
            _noFlowLabel.text = [NSBundle mxk_localizedStringForKey:@"login_error_registration_is_not_supported"];
        }
        NSLog(@"[MXKAuthenticationVC] Warning: %@", _noFlowLabel.text);
        
        if (authenticationFallback.length)
        {
            [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"login_use_fallback"] forState:UIControlStateNormal];
            [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"login_use_fallback"] forState:UIControlStateNormal];
        }
        else
        {
            [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"retry"] forState:UIControlStateNormal];
            [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"retry"] forState:UIControlStateNormal];
        }
        
        _noFlowLabel.hidden = NO;
        _retryButton.hidden = NO;
    }
}

- (void)setSelectedFlow:(MXLoginFlow *)inSelectedFlow
{
    // Hide views which depend on auth flow
    _submitButton.hidden = YES;
    _noFlowLabel.hidden = YES;
    _retryButton.hidden = YES;
    
    [currentAuthInputsView removeFromSuperview];
    currentAuthInputsView.delegate = nil;
    currentAuthInputsView = nil;
    
    // C-S API v2: Consider the first flow from stages as current type
    if (inSelectedFlow.type == nil && inSelectedFlow.stages.count)
    {
        inSelectedFlow.type = inSelectedFlow.stages.firstObject;
    }
    
    // Create the right auth inputs view
    NSDictionary *authInputsViewMap;
    if (self.authType == MXKAuthenticationTypeLogin)
    {
        authInputsViewMap = loginAuthInputsViewMap;
    }
    else
    {
        authInputsViewMap = registerAuthInputsViewMap;
    }
    
    Class class = authInputsViewMap[inSelectedFlow.type];
    if (class)
    {
        currentAuthInputsView = [class authInputsView];
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
    
    selectedFlow = inSelectedFlow;
}

- (void)onFailureDuringMXOperation:(NSError*)error
{
    mxCurrentOperation = nil;
    
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
    {
        // Ignore this error
        return;
    }
    
    [_authenticationActivityIndicator stopAnimating];
    
    // Alert user
    NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
    if (!title)
    {
        title = [NSBundle mxk_localizedStringForKey:@"error"];
    }
    NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    
    alert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
    alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"dismiss"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                               {}];
    [alert showInViewController:self];
    
    // Display failure reason
    _noFlowLabel.hidden = NO;
    _noFlowLabel.text = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
    if (!_noFlowLabel.text.length)
    {
        _noFlowLabel.text = [NSBundle mxk_localizedStringForKey:@"login_error_no_login_flow"];
    }
    [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"retry"] forState:UIControlStateNormal];
    [_retryButton setTitle:[NSBundle mxk_localizedStringForKey:@"retry"] forState:UIControlStateNormal];
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
        _noFlowLabel.text = [NSBundle mxk_localizedStringForKey:@"network_error_not_reachable"];
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
                if ([self.selectedFlow.type isEqualToString:kMXLoginFlowTypePassword])
                {
                    MXKAuthInputsPasswordBasedView *authInputsView = (MXKAuthInputsPasswordBasedView*)currentAuthInputsView;
                    
                    NSString *user = authInputsView.userLoginTextField.text;
                    user = [user stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                    [mxRestClient loginWithUser:user andPassword:authInputsView.passWordTextField.text
                                        success:^(MXCredentials *credentials){
                                            [_authenticationActivityIndicator stopAnimating];
                                            
                                            [self onSuccessfulLogin:credentials];
                                        }
                                        failure:^(NSError *error){
                                            [self onFailureDuringAuthRequest:error];
                                        }];
                }
                else
                {
                    // FIXME
                    [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]];
                }
            }
            else
            {
                // FIXME
                [self onFailureDuringAuthRequest:[NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]];
            }
        }
    }
    else if (sender == _authSwitchButton)
    {
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
        if (authenticationFallback)
        {
            [self showAuthenticationFallBackView:authenticationFallback];
        }
        else
        {
            [self refreshSupportedAuthFlow];
        }
    }
    else if (sender == _cancelAuthFallbackButton)
    {
        // Hide fallback webview
        [self hideRegistrationFallbackView];
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
                message = [NSBundle mxk_localizedStringForKey:@"login_error_forbidden"];
            }
            else if ([errCode isEqualToString:@"M_UNKNOWN_TOKEN"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_unknown_token"];
            }
            else if ([errCode isEqualToString:@"M_BAD_JSON"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_bad_json"];
            }
            else if ([errCode isEqualToString:@"M_NOT_JSON"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_not_json"];
            }
            else if ([errCode isEqualToString:@"M_LIMIT_EXCEEDED"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_limit_exceeded"];
            }
            else if ([errCode isEqualToString:@"M_USER_IN_USE"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_user_in_use"];
            }
            else if ([errCode isEqualToString:@"M_LOGIN_EMAIL_URL_NOT_YET"])
            {
                message = [NSBundle mxk_localizedStringForKey:@"login_error_login_email_not_yet"];
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
    
    // Alert user
    alert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"login_error_title"] message:message style:MXKAlertStyleAlert];
    [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"dismiss"] style:MXKAlertActionStyleCancel handler:^(MXKAlert *alert)
     {}];
    [alert showInViewController:self];
}

- (void)onSuccessfulLogin:(MXCredentials*)credentials
{
    // Sanity check: check whether the user is not already logged in with this id
    if ([[MXKAccountManager sharedManager] accountForUserId:credentials.userId])
    {
        //Alert user
        __weak typeof(self) weakSelf = self;
        alert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"login_error_already_logged_in"] message:nil style:MXKAlertStyleAlert];
        [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleCancel handler:^(MXKAlert *alert) {
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
        
        [[MXKAccountManager sharedManager] addAccount:account andOpenSession:YES];
        
        if (_delegate)
        {
            [_delegate authenticationViewController:self didLogWithUserId:credentials.userId];
        }
    }
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

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField == _homeServerTextField)
    {
        // Cancel supported AuthFlow refresh if a request is in progress
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
        
        if (mxCurrentOperation)
        {
            // Cancel potential request in progress
            [mxCurrentOperation cancel];
            mxCurrentOperation = nil;
        }
        
        [_authenticationActivityIndicator stopAnimating];
    }

    return YES;
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
        
        [self updateRESTClient];
        
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

#pragma mark - Authentication Fallback

- (void)showAuthenticationFallBackView:(NSString*)fallbackPage
{
    _authenticationScrollView.hidden = YES;
    _authFallbackContentView.hidden = NO;
    
    // Add a cancel button in case of navigation controller use.
    if (self.navigationController)
    {
        if (!cancelFallbackBarButton)
        {
            cancelFallbackBarButton = [[UIBarButtonItem alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"login_leave_fallback"] style:UIBarButtonItemStylePlain target:self action:@selector(hideRegistrationFallbackView)];
        }
        
        // Add cancel button in right bar items
        NSArray *rightBarButtonItems = self.navigationItem.rightBarButtonItems;
        self.navigationItem.rightBarButtonItems = rightBarButtonItems ? [rightBarButtonItems arrayByAddingObject:cancelFallbackBarButton] : @[cancelFallbackBarButton];
    }
    
    [_authFallbackWebView openFallbackPage:fallbackPage success:^(MXCredentials *credentials) {
        
        // Workaround: HS does not return the right URL. Use the one we used to make the request
        credentials.homeServer = mxRestClient.homeserver;
        
        // TODO handle unrecognized certificate (if any) during registration through fallback webview.
        
        [self onSuccessfulLogin:credentials];
    }];
}

- (void)hideRegistrationFallbackView
{
    if (cancelFallbackBarButton)
    {
        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray: self.navigationItem.rightBarButtonItems];
        [rightBarButtonItems removeObject:cancelFallbackBarButton];
        self.navigationItem.rightBarButtonItems = rightBarButtonItems;
    }
    
    [_authFallbackWebView stopLoading];
    _authenticationScrollView.hidden = NO;
    _authFallbackContentView.hidden = YES;
}

@end
