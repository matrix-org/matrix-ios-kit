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

@interface MXKViewController ()
{
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    
    /**
     Keep reference on the pushed view controllers to release them correctly
     */
    NSMutableArray *childViewControllers;
}
@end

@implementation MXKViewController
@synthesize defaultBarTintColor, enableBarTintColorStatusChange;
@synthesize mainSession;
@synthesize activityIndicator, rageShakeManager;
@synthesize childViewControllers;

#pragma mark -

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self finalizeInit];
    }
    
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self finalizeInit];
    }
    
    return self;
}

- (void)finalizeInit
{
    // Set default properties values
    defaultBarTintColor = nil;
    enableBarTintColorStatusChange = YES;
    
    mxSessionArray = [NSMutableArray array];
    childViewControllers = [NSMutableArray array];
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Add default activity indicator
    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityIndicator.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
    activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    activityIndicator.hidesWhenStopped = YES;
    
    CGRect frame = activityIndicator.frame;
    frame.size.width += 30;
    frame.size.height += 30;
    activityIndicator.bounds = frame;
    [activityIndicator.layer setCornerRadius:5];
    
    activityIndicator.center = self.view.center;
    [self.view addSubview:activityIndicator];
}

- (void)dealloc
{
    if (activityIndicator)
    {
        [activityIndicator removeFromSuperview];
        activityIndicator = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.rageShakeManager)
    {
        [self.rageShakeManager cancel:self];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // Update UI according to mxSession state, and add observer (if need)
    if (mxSessionArray.count)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixSessionStateDidChange:) name:kMXSessionStateDidChangeNotification object:nil];
    }
    [self onMatrixSessionChange];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionStateDidChangeNotification object:nil];
    
    [activityIndicator stopAnimating];
    
    if (self.rageShakeManager)
    {
        [self.rageShakeManager cancel:self];
    }

    // Remove keyboard view (if any)
    self.keyboardView = nil;
    self.keyboardHeight = 0;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Release properly pushed and/or presented view controller
    if (childViewControllers.count)
    {
        for (id viewController in childViewControllers)
        {
            if ([viewController isKindOfClass:[UINavigationController class]])
            {
                UINavigationController *navigationController = (UINavigationController*)viewController;
                for (id subViewController in navigationController.viewControllers)
                {
                    if ([subViewController respondsToSelector:@selector(destroy)])
                    {
                        [subViewController destroy];
                    }
                }
            }
            else if ([viewController respondsToSelector:@selector(destroy)])
            {
                [viewController destroy];
            }
        }
        
        [childViewControllers removeAllObjects];
    }
}

- (void)setEnableBarTintColorStatusChange:(BOOL)enable
{
    if (enableBarTintColorStatusChange != enable)
    {
        enableBarTintColorStatusChange = enable;
        
        [self onMatrixSessionChange];
    }
}

- (void)setView:(UIView *)view
{
    [super setView:view];
    
    // Keep the activity indicator (if any)
    if (activityIndicator)
    {
        activityIndicator.center = self.view.center;
        [self.view addSubview:activityIndicator];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Keep ref on destinationViewController
    [childViewControllers addObject:segue.destinationViewController];
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion
{
    // Keep ref on presented view controller
    [childViewControllers addObject:viewControllerToPresent];
    
    [super presentViewController:viewControllerToPresent animated:YES completion:nil];
}

#pragma mark -

- (void)addMatrixSession:(MXSession*)mxSession
{
    if (!mxSession || mxSession.state == MXSessionStateClosed)
    {
        return;
    }
    
    if (!mxSessionArray.count)
    {
        [mxSessionArray addObject:mxSession];
        
        // Add matrix sessions observer on first added session
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixSessionStateDidChange:) name:kMXSessionStateDidChangeNotification object:nil];
    }
    else if ([mxSessionArray indexOfObject:mxSession] == NSNotFound)
    {
        [mxSessionArray addObject:mxSession];
    }
    
    // Force update
    [self onMatrixSessionChange];
}

- (void)removeMatrixSession:(MXSession*)mxSession
{
    if (!mxSession)
    {
        return;
    }
    
    NSUInteger index = [mxSessionArray indexOfObject:mxSession];
    if (index != NSNotFound)
    {
        [mxSessionArray removeObjectAtIndex:index];
        
        if (!mxSessionArray.count)
        {
            // Remove matrix sessions observer
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionStateDidChangeNotification object:nil];
        }
    }
    
    // Force update
    [self onMatrixSessionChange];
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}

- (MXSession*)mainSession
{
    // We consider the first added session as the main one.
    if (mxSessionArray.count)
    {
        return [mxSessionArray firstObject];
    }
    return nil;
}

#pragma mark -

- (void)withdrawViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    // Check whether the view controller is embedded inside a navigation controller.
    if (self.navigationController)
    {
        // We pop the view controller (except if it is the root view controller).
        NSUInteger index = [self.navigationController.viewControllers indexOfObject:self];
        if (index != NSNotFound)
        {
            if (index > 0)
            {
                UIViewController *previousViewController = [self.navigationController.viewControllers objectAtIndex:(index - 1)];
                [self.navigationController popToViewController:previousViewController animated:animated];
                
                if (completion)
                {
                    completion();
                }
            }
            else
            {
                [self.navigationController dismissViewControllerAnimated:animated completion:completion];
            }
        }
    }
    else
    {
        // Suppose here the view controller has been presented modally. We dismiss it
        [self dismissViewControllerAnimated:animated completion:completion];
    }
}

- (void)destroy
{
    // Remove properly keyboard view (remove related key observers)
    self.keyboardView = nil;
    
    // Remove observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    mxSessionArray = nil;
    childViewControllers = nil;
}

#pragma mark - Sessions handling

- (void)onMatrixSessionStateDidChange:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    
    NSUInteger index = [mxSessionArray indexOfObject:mxSession];
    if (index != NSNotFound)
    {
        if (mxSession.state == MXSessionStateClosed)
        {
            // Call here the dedicated method which may be overridden
            [self removeMatrixSession:mxSession];
        }
        else
        {
            [self onMatrixSessionChange];
        }
    }
}

- (void)onMatrixSessionChange
{
    // This method is called to refresh view controller appearance on session state change,
    // It is called when the view will appear to update session array by removing closed sessions.
    // Indeed 'kMXSessionStateDidChangeNotification' are observed only when the view controller is visible.

    // Retrieve the main navigation controller if the current view controller is embedded inside a split view controller.
    UINavigationController *mainNavigationController = nil;
    if (self.splitViewController)
    {
        mainNavigationController = self.navigationController;
        UIViewController *parentViewController = self.parentViewController;
        while (parentViewController)
        {
            if (parentViewController.navigationController)
            {
                mainNavigationController = parentViewController.navigationController;
                parentViewController = parentViewController.parentViewController;
            }
            else
            {
                break;
            }
        }
    }

    if (mxSessionArray.count)
    {
        // Check each session state.
        UIColor *barTintColor = defaultBarTintColor;
        BOOL allHomeserverNotReachable = YES;
        BOOL isActivityInProgress = NO;
        for (NSUInteger index = 0; index < mxSessionArray.count;)
        {
            MXSession *mxSession = mxSessionArray[index];
            
            // Remove here closed sessions
            if (mxSession.state == MXSessionStateClosed)
            {
                // Call here the dedicated method which may be overridden.
                // This method will call again [onMatrixSessionChange] when session is removed.
                [self removeMatrixSession:mxSession];
                return;
            }
            else
            {
                if (mxSession.state == MXSessionStateHomeserverNotReachable)
                {
                    barTintColor = [UIColor orangeColor];
                }
                else
                {
                    allHomeserverNotReachable = NO;
                    
                    if (mxSession.state == MXSessionStateSyncInProgress || mxSession.state == MXSessionStateInitialised)
                    {
                        isActivityInProgress = YES;
                    }
                }
                
                index++;
            }
        }
        
        // Check whether the navigation bar color depends on homeserver reachability.
        if (enableBarTintColorStatusChange)
        {
            // The navigation bar tintColor reflects the matrix homeserver reachability status.
            if (allHomeserverNotReachable)
            {
                self.navigationController.navigationBar.barTintColor = [UIColor redColor];
                if (mainNavigationController)
                {
                    mainNavigationController.navigationBar.barTintColor = [UIColor redColor];
                }
            }
            else
            {
                self.navigationController.navigationBar.barTintColor = barTintColor;
                if (mainNavigationController)
                {
                    mainNavigationController.navigationBar.barTintColor = barTintColor;
                }
            }
        }
        
        // Run activity indicator if need
        if (isActivityInProgress)
        {
            [self startActivityIndicator];
        }
        else
        {
            [self stopActivityIndicator];
        }
    }
    else
    {
        // Hide potential activity indicator
        [self stopActivityIndicator];
        
        // Restore default tintColor
        self.navigationController.navigationBar.barTintColor = defaultBarTintColor;
        if (mainNavigationController)
        {
            mainNavigationController.navigationBar.barTintColor = defaultBarTintColor;
        }
    }
}

#pragma mark - Activity indicator

- (void)startActivityIndicator
{
    [self.view bringSubviewToFront:activityIndicator];
    [activityIndicator startAnimating];

    // Show the loading wheel after a delay so that if the caller calls stopActivityIndicator
    // in a short future, the loading wheel will not be displayed to the end user.
    activityIndicator.alpha = 0;
    [UIView animateWithDuration:0.3 delay:0.3 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        activityIndicator.alpha = 1;
    } completion:^(BOOL finished)
     {
     }];
}

- (void)stopActivityIndicator
{
    // Check whether all conditions are satisfied before stopping loading wheel
    BOOL isActivityInProgress = NO;
    for (MXSession *mxSession in mxSessionArray)
    {
        if (mxSession.state == MXSessionStateSyncInProgress || mxSession.state == MXSessionStateInitialised)
        {
            isActivityInProgress = YES;
        }
    }
    if (!isActivityInProgress)
    {
        [activityIndicator stopAnimating];
    }
}

#pragma mark - Shake handling

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake && self.rageShakeManager)
    {
        [self.rageShakeManager startShaking:self];
    }
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [self motionEnded:motion withEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (self.rageShakeManager)
    {
        [self.rageShakeManager stopShaking:self];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return (self.rageShakeManager != nil);
}

#pragma mark - Keyboard handling

- (void)onKeyboardShowAnimationComplete
{
    // Do nothing here - `MXKViewController-inherited` instance must override this method.
}

- (void)setKeyboardView:(UIView *)keyboardView
{  
    // Remove previous keyboardView if any
    if (_keyboardView)
    {
        // Restore UIKeyboardWillShowNotification observer
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        
        // Remove keyboard view observers
        [_keyboardView removeObserver:self forKeyPath:NSStringFromSelector(@selector(frame))];
        [_keyboardView removeObserver:self forKeyPath:NSStringFromSelector(@selector(center))];
        
        _keyboardView = nil;
    }
    
    if (keyboardView)
    {
        // Add observers to detect keyboard drag down
        [keyboardView addObserver:self forKeyPath:NSStringFromSelector(@selector(frame)) options:0 context:nil];
        [keyboardView addObserver:self forKeyPath:NSStringFromSelector(@selector(center)) options:0 context:nil];
        
        // Remove UIKeyboardWillShowNotification observer to ignore this notification until keyboard is dismissed.
        // Note: UIKeyboardWillShowNotification may be triggered several times before keyboard is dismissed,
        // because the keyboard height is updated (switch to a Chinese keyboard for example).
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
        
        _keyboardView = keyboardView;
    }
}

- (void)onKeyboardWillShow:(NSNotification *)notif
{
    // Get the keyboard size
    NSValue *rectVal = notif.userInfo[UIKeyboardFrameEndUserInfoKey];
    CGRect endRect = rectVal.CGRectValue;
    
    // IOS 8 triggers some unexpected keyboard events
    if ((endRect.size.height == 0) || (endRect.size.width == 0))
    {
        return;
    }
    
    // Get the animation info
    NSNumber *curveValue = [[notif userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve animationCurve = curveValue.intValue;
    // The duration is ignored but it is better to define it
    double animationDuration = [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // Apply keyboard animation
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | (animationCurve << 16) animations:^{
        // Set the new keyboard height by checking screen orientation
        self.keyboardHeight = (endRect.origin.y == 0) ? endRect.size.width : endRect.size.height;
    } completion:^(BOOL finished)
    {
        [self onKeyboardShowAnimationComplete];
    }];
}

- (void)onKeyboardWillHide:(NSNotification *)notif
{
    // Remove keyboard view
    self.keyboardView = nil;
    
    // Get the animation info
    NSNumber *curveValue = [[notif userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    UIViewAnimationCurve animationCurve = curveValue.intValue;
    // the duration is ignored but it is better to define it
    double animationDuration = [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // Apply keyboard animation
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | (animationCurve << 16) animations:^{
        self.keyboardHeight = 0;
    } completion:^(BOOL finished)
    {
    }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == _keyboardView) && ([keyPath isEqualToString:NSStringFromSelector(@selector(frame))] || [keyPath isEqualToString:NSStringFromSelector(@selector(center))]))
    {
        
        // The keyboard view has been modified (Maybe the user drag it down), we update the input toolbar bottom constraint to adjust layout.
        
        // Compute keyboard height
        CGSize screenSize = [[UIScreen mainScreen] bounds].size;
        // on IOS 8, the screen size is oriented
        if ((NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
        {
            screenSize = CGSizeMake(screenSize.height, screenSize.width);
        }
        self.keyboardHeight = screenSize.height - _keyboardView.frame.origin.y;
    }
}

@end