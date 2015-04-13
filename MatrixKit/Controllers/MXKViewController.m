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

#import "MXKViewController.h"

@interface MXKViewController () {
    id mxkViewControllerSessionStateObserver;
}
@end

@implementation MXKViewController
@synthesize mxSession;
@synthesize activityIndicator, rageShakeManager;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Add default activity indicator
    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityIndicator.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
    activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    CGRect frame = activityIndicator.frame;
    frame.size.width += 30;
    frame.size.height += 30;
    activityIndicator.bounds = frame;
    [activityIndicator.layer setCornerRadius:5];
    
    activityIndicator.center = self.view.center;
    [self.view addSubview:activityIndicator];
}

- (void)dealloc {
    if (activityIndicator) {
        [activityIndicator removeFromSuperview];
        activityIndicator = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.rageShakeManager) {
        [self.rageShakeManager cancel:self];
    }
    
    if (mxSession) {
        // Register mxSession observer
        self.mxSession = mxSession;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:mxkViewControllerSessionStateObserver];
    [activityIndicator stopAnimating];
    
    if (self.rageShakeManager) {
        [self.rageShakeManager cancel:self];
    }
}

- (void)setView:(UIView *)view {
    [super setView:view];
    
    // Keep the activity indicator (if any)
    if (activityIndicator) {
        activityIndicator.center = self.view.center;
        [self.view addSubview:activityIndicator];
    }
}

#pragma mark -

- (void)setMxSession:(MXSession *)session {
    // Remove potential session observer
    [[NSNotificationCenter defaultCenter] removeObserver:mxkViewControllerSessionStateObserver];
    
    if (session) {
        // Register session state observer
        mxkViewControllerSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:MXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // Check whether the concerned session is the associated one
            if (notif.object == mxSession) {
                [self didMatrixSessionStateChange];
            }
        }];
    }
    
    mxSession = session;
    
    // Force update
    [self didMatrixSessionStateChange];
}

- (void)didMatrixSessionStateChange {
    // Retrieve the main navigation controller if the current view controller is embedded inside a split view controller.
    UINavigationController *mainNavigationController = nil;
    if (self.splitViewController) {
        mainNavigationController = self.navigationController;
        UIViewController *parentViewController = self.parentViewController;
        while (parentViewController) {
            if (parentViewController.navigationController) {
                mainNavigationController = parentViewController.navigationController;
                parentViewController = parentViewController.parentViewController;
            } else {
                break;
            }
        }
    }
    
    if (mxSession) {
        // The navigation bar tintColor depends on matrix homeserver reachability status
        if (mxSession.state == MXSessionStateHomeserverNotReachable) {
            self.navigationController.navigationBar.barTintColor = [UIColor redColor];
            if (mainNavigationController) {
                mainNavigationController.navigationBar.barTintColor = [UIColor redColor];
            }
        } else {
            // Restore default tintColor
            self.navigationController.navigationBar.barTintColor = nil;
            if (mainNavigationController) {
                mainNavigationController.navigationBar.barTintColor = nil;
            }
        }
        
        // Run activity indicator if need
        if (mxSession.state == MXSessionStateSyncInProgress || mxSession.state == MXSessionStateInitialised) {
            [self startActivityIndicator];
        } else {
            [self stopActivityIndicator];
        }
    } else {
        // Hide potential activity indicator
        [self stopActivityIndicator];
        
        // Restore default tintColor
        self.navigationController.navigationBar.barTintColor = nil;
        if (mainNavigationController) {
            mainNavigationController.navigationBar.barTintColor = nil;
        }
    }
}

#pragma mark - activity indicator

- (void)startActivityIndicator {
    [self.view bringSubviewToFront:activityIndicator];
    [activityIndicator startAnimating];
}

- (void)stopActivityIndicator {
    // Check whether all conditions are satisfied before stopping loading wheel
    if (!mxSession || (mxSession.state != MXSessionStateSyncInProgress && mxSession.state != MXSessionStateInitialised)) {
        [activityIndicator stopAnimating];
    }
}

#pragma mark - Shake handling

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake && self.rageShakeManager) {
        [self.rageShakeManager startShaking:self];
    }
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    [self motionEnded:motion withEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (self.rageShakeManager) {
        [self.rageShakeManager stopShaking:self];
    }
}

- (BOOL)canBecomeFirstResponder {
    return (self.rageShakeManager != nil);
}


@end