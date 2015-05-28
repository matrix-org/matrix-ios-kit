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
#import <MatrixSDK/MatrixSDK.h>

#import "MXKViewController.h"

#import "MXKImageView.h"

@class MXKCallViewController;

/**
 Delegate for `MXKCallViewController` object
 */
@protocol MXKCallViewControllerDelegate <NSObject>

/**
 Tells the delegate to dismiss the call view controller.
 This callback is called when the user wants to go back into the app during a call or when the call is ended.
 The delegate should check the state of the associated call to know the actual reason.
 */
- (void)dismissCallViewController:(MXKCallViewController *)callViewController;

@end

extern NSString *const kMXKCallViewControllerWillAppearNotification;
extern NSString *const kMXKCallViewControllerAppearedNotification;
extern NSString *const kMXKCallViewControllerWillDisappearNotification;
extern NSString *const kMXKCallViewControllerDisappearedNotification;
extern NSString *const kMXKCallViewControllerBackToAppNotification;

/**
 'MXKCallViewController' instance displays a call. Only one matrix session is supported by this view controller.
 */
@interface MXKCallViewController : MXKViewController <MXCallDelegate> {
}

@property (weak, nonatomic, readonly) IBOutlet MXKImageView *backgroundImageView;

@property (weak, nonatomic, readonly) IBOutlet UIView *localPreviewContainerView;
@property (weak, nonatomic, readonly) IBOutlet UIActivityIndicatorView *localPreviewActivityView;

@property (weak, nonatomic, readonly) IBOutlet UIView *remotePreviewContainerView;

@property (weak, nonatomic, readonly) IBOutlet UIView *overlayContainerView;
@property (weak, nonatomic, readonly) IBOutlet UIView *callContainerView;
@property (weak, nonatomic, readonly) IBOutlet MXKImageView *callerImageView;
@property (weak, nonatomic, readonly) IBOutlet UILabel *callerNameLabel;
@property (weak, nonatomic, readonly) IBOutlet UILabel *callStatusLabel;

@property (weak, nonatomic, readonly) IBOutlet UIView *callToolBar;
@property (weak, nonatomic, readonly) IBOutlet UIButton *rejectCallButton;
@property (weak, nonatomic, readonly) IBOutlet UIButton *answerCallButton;
@property (weak, nonatomic, readonly) IBOutlet UIButton *endCallButton;

@property (weak, nonatomic, readonly) IBOutlet UIView *callControlContainerView;
@property (weak, nonatomic, readonly) IBOutlet UIButton *speakerButton;
@property (weak, nonatomic, readonly) IBOutlet UIButton *muteButton;

@property (weak, nonatomic, readonly) IBOutlet UIButton *backToAppButton;

@property (nonatomic, readonly) UIWindow* backToAppStatusWindow;

@property (nonatomic, readonly) MXCall *mxCall;

/**
 YES when the presentation of the view controller is complete.
 */
@property (nonatomic) BOOL isPresented;

/**
 The delegate.
 */
@property (nonatomic, weak) id<MXKCallViewControllerDelegate> delegate;

#pragma mark - Class methods

/**
 Returns the `UINib` object initialized for a `MXKCallViewController`.
 
 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `roomViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKCallViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 
 @param call a MXCall instance.
 @return An initialized `MXKRoomViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)callViewController:(MXCall*)call;

///**
// Display an incoming call.
// 
// @param call MXCall instance.
// */
//- (void)handleCall:(MXCall*)call;

- (IBAction)onButtonPressed:(id)sender;

@end
