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

#import <UIKit/UIKit.h>

#import "MXKViewController.h"

#import "MXKAuthInputsView.h"
#import "MXKRegistrationWebView.h"

@class MXKAuthenticationViewController;

/**
 `MXKAuthenticationViewController` delegate.
 */
@protocol MXKAuthenticationViewControllerDelegate <NSObject>

/**
 Tells the delegate the authentication process succeeded to add a new account.
 
 @param authenticationViewController the `MXKAuthenticationViewController` instance.
 @param userId the user id of the new added account.
 */
- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString*)userId;

@end

/**
 This view controller should be used to manage registration or login flows with matrix home server.
 
 Only the flow based on password is presently supported. Other flows should be added later.
 
 You may add a delegate to be notified when a new account has been added successfully.
 */
@interface MXKAuthenticationViewController : MXKViewController <UITextFieldDelegate, MXKAuthInputsViewDelegate>

/**
 The current authentication type
 */
@property (nonatomic) MXKAuthenticationType authType;

/**
 The current selected login flow
 */
@property (nonatomic) MXLoginFlow *selectedFlow;

/**
 The default home server url (nil by default).
 */
@property (nonatomic) NSString *defaultHomeServerUrl;

/**
 The default identity server url (nil by default).
 */
@property (nonatomic) NSString *defaultIdentityServerUrl;

/**
 The delegate for the view controller.
 */
@property (nonatomic) id<MXKAuthenticationViewControllerDelegate> delegate;

/**
 *  Returns the `UINib` object initialized for a `MXKAuthenticationViewController`.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during initialization
 *  or the nib file could not be located.
 *
 *  @discussion You may override this method to provide a customized nib. If you do,
 *  you should also override `authenticationViewController` to return your
 *  view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 *  Creates and returns a new `MXKAuthenticationViewController` object.
 *
 *  @discussion This is the designated initializer for programmatic instantiation.
 *
 *  @return An initialized `MXKAuthenticationViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)authenticationViewController;

/**
 Check whether the provided flow is supported by `MXKAuthenticationViewController` implementation.
 
 @param flowType a flow type.
 @param authType the concerned authentication type
 @return YES if the provided flow is supported.
 */
+ (BOOL)isImplementedFlowType:(MXLoginFlowType)flowType forAuthType:(MXKAuthenticationType)authType;

@end

