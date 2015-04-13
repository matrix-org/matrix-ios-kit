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

#import <Foundation/Foundation.h>

#import <MatrixSDK/MatrixSDK.h>

#import "MXKResponderRageShaking.h"

/**
 `MXKViewControllerHandling` defines a protocol to handle requirements for
 all matrixKit view controllers and table view controllers.
 
 It manages the following points:
 - stop/start activity indicator according to associated matrix session state.
 - update view appearance on matrix session state change.
 - support rage shake mechanism (depend on `rageShakeManager` property).
 */
@protocol MXKViewControllerHandling <NSObject>

/**
 Associated matrix session (nil by default).
 This property is used to update view appearance according to the session state.
 */
@property (nonatomic) MXSession *mxSession;

/**
 An object implementing the `MXKResponderRageShaking` protocol.
 The view controller uses this object (if any) to report beginning and end of potential
 rage shake when it is the first responder.
 
 This property is nil by default.
 */
@property (nonatomic) id<MXKResponderRageShaking> rageShakeManager;

/**
 Activity indicator view.
 By default this activity indicator is centered inside the view controller view. It is automatically
 start on the following matrix session states: `MXSessionStateInitialised` and `MXSessionStateSyncInProgress`.
 It is stopped on other states.
 Set nil to disable activity indicator animation.
 */
@property (nonatomic) UIActivityIndicatorView *activityIndicator;

/**
 Update view controller appearance according to the state of its associated matrix session.
 This method is called on session state change (see `MXSessionStateDidChangeNotification`).
 
 The default implementation:
 - switches in red the navigation bar tintColor on `MXSessionStateHomeserverNotReachable`
 - starts activity indicator on `MXSessionStateInitialised` and `MXSessionStateSyncInProgress`.
 
 Override it to customize view appearance according to session state.
 */
- (void)didMatrixSessionStateChange;

/**
 Bring the activity indicator to the front and start it.
 */
- (void)startActivityIndicator;

/**
 Stop the activity indicator if all conditions are satisfied.
 */
- (void)stopActivityIndicator;


@end

