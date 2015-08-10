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

#define MXKROOMVIEWCONTROLLER_DEFAULT_TYPING_TIMEOUT_SEC 10
#define MXKROOMVIEWCONTROLLER_MESSAGES_TABLE_MINIMUM_HEIGHT 50

#define MXKROOMVIEWCONTROLLER_BACK_PAGINATION_MAX_SCROLLING_OFFSET 100

#import "MXKRoomViewController.h"

#import <MediaPlayer/MediaPlayer.h>

#import "MXKRoomBubbleTableViewCell.h"
#import "MXKImageView.h"
#import "MXKEventDetailsView.h"

#import "MXKRoomInputToolbarViewWithSimpleTextView.h"

#import "MXKConstants.h"

#import "NSBundle+MatrixKit.h"

NSString *const kCmdChangeDisplayName = @"/nick";
NSString *const kCmdEmote = @"/me";
NSString *const kCmdJoinRoom = @"/join";
NSString *const kCmdKickUser = @"/kick";
NSString *const kCmdBanUser = @"/ban";
NSString *const kCmdUnbanUser = @"/unban";
NSString *const kCmdSetUserPowerLevel = @"/op";
NSString *const kCmdResetUserPowerLevel = @"/deop";

@interface MXKRoomViewController ()
{
    /**
     Potential event details view.
     */
    MXKEventDetailsView *eventDetailsView;
    
    /**
     Current alert (if any).
     */
    MXKAlert *currentAlert;
    
    /**
     Boolean value used to scroll to bottom the bubble history at first display.
     */
    BOOL shouldScrollToBottomOnTableRefresh;
    
    /**
     YES if scrolling to bottom is in progress
     */
    BOOL isScrollingToBottom;
    
    /**
     Date of the last observed typing
     */
    NSDate *lastTypingDate;
    
    /**
     Local typing timout
     */
    NSTimer* typingTimer;
    
    /**
     YES when back pagination is in progress.
     */
    BOOL isBackPaginationInProgress;
    
    /**
     Store current number of bubbles before back pagination.
     */
    NSInteger backPaginationSavedBubblesNb;
    
    /**
     Store the height of the first bubble before back pagination.
     */
    CGFloat backPaginationSavedFirstBubbleHeight;
    
    /**
     Potential request in progress to join the selected room
     */
    MXHTTPOperation *joinRoomRequest;
    
    /**
     Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
     */
    id kMXSessionWillLeaveRoomNotificationObserver;
    
    /**
     Observe UIMenuControllerDidHideMenuNotification to cancel text selection
     */
    id UIMenuControllerDidHideMenuNotificationObserver;
    NSString *selectedText;
    
    /**
     Observe Attachment download
     */
    id onAttachmentDownloadFailureObs;
    id onAttachmentDownloadEndObs;
    
    /**
     The document interaction Controller used to share attachment
     */
    UIDocumentInteractionController *documentInteractionController;
    
    /**
     The temporary symbolic link defined with the original attachment name
     */
    NSString *documentSymbolicLinkPath;
    
    // Attachment handling
    MXKImageView *highResImageView;
    NSString *AVAudioSessionCategory;
    MPMoviePlayerController *videoPlayer;
    MPMoviePlayerController *tmpVideoPlayer;
    NSString *selectedVideoURL;
    NSString *selectedVideoCachePath;
}

@end

@implementation MXKRoomViewController
@synthesize roomDataSource, titleView, inputToolbarView;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomViewController class]]];
}

+ (instancetype)roomViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomViewController class]]];
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!_bubblesTableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // Adjust bottom constraint of the input toolbar container in order to take into account potential tabBar
    if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)])
    {
        [NSLayoutConstraint deactivateConstraints:@[_roomInputToolbarContainerBottomConstraint]];
    }
    else
    {
        [self.view removeConstraint:_roomInputToolbarContainerBottomConstraint];
    }
    
    _roomInputToolbarContainerBottomConstraint = [NSLayoutConstraint constraintWithItem:self.bottomLayoutGuide
                                                                              attribute:NSLayoutAttributeTop
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:self.roomInputToolbarContainer
                                                                              attribute:NSLayoutAttributeBottom
                                                                             multiplier:1.0f
                                                                               constant:0.0f];
    if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
    {
        [NSLayoutConstraint activateConstraints:@[_roomInputToolbarContainerBottomConstraint]];
    }
    else
    {
        [self.view addConstraint:_roomInputToolbarContainerBottomConstraint];
    }
    [self.view setNeedsUpdateConstraints];
    
    // Hide bubbles table by default in order to hide initial scrolling to the bottom
    _bubblesTableView.hidden = YES;
    
    // Ensure that the titleView will be scaled when it will be required
    // during a screen rotation for example.
    _roomTitleViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // Set default input toolbar view
    [self setRoomInputToolbarViewClass:MXKRoomInputToolbarViewWithSimpleTextView.class];
    
    // Scroll to bottom the bubble history at first display
    shouldScrollToBottomOnTableRefresh = YES;
    
    // Save progress text input
    _saveProgressTextInput = YES;
    
    // Check whether a room source has been defined
    if (roomDataSource)
    {
        [self configureView];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Observe server sync process at room data source level too
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixSessionChange) name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    
    // Finalize view controller appearance
    [self updateViewControllerAppearanceOnRoomDataSourceState];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Refresh bubbles table if data are available.
    // Note: This operation is not done during `viewWillAppear:` because the view controller is not added to a view hierarchy yet. The table layout is not valid then to apply scroll to bottom mechanism.
    if (roomDataSource.state == MXKDataSourceStateReady && [roomDataSource tableView:_bubblesTableView numberOfRowsInSection:0])
    {
        [self reloadBubblesTable];
    }
    _bubblesTableView.hidden = NO;
    shouldScrollToBottomOnTableRefresh = NO;
    
    if (_saveProgressTextInput && roomDataSource)
    {
        // Retrieve the potential message partially typed during last room display.
        // Note: We have to wait for viewDidAppear before updating growingTextView (viewWillAppear is too early)
        inputToolbarView.textMessage = roomDataSource.partialTextMessage;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (_saveProgressTextInput && roomDataSource)
    {
        // Store the potential message partially typed in text input
        roomDataSource.partialTextMessage = inputToolbarView.textMessage;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceSyncStatusChanged object:nil];
}

- (void)dealloc
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(coordinator.transitionDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.keyboardView)
        {
            [self updateMessageTextViewFrame];
        }
        // Cell width will be updated, force table refresh to take into account changes of message components
        [self reloadBubblesTable];
    });
}

// The 2 following methods are deprecated since iOS 8
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // Cell width will be updated, force table refresh to take into account changes of message components
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadBubblesTable];
    });
}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    if (!self.keyboardView)
    {
        [self updateMessageTextViewFrame];
    }
}

#pragma mark - Override MXKViewController

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    // Check dataSource state
    if (self.roomDataSource && (self.roomDataSource.state == MXKDataSourceStatePreparing || self.roomDataSource.serverSyncEventCount))
    {
        // dataSource is not ready, keep running the loading wheel
        [self.activityIndicator startAnimating];
    }
}

- (void)onKeyboardShowAnimationComplete
{
    // Check first if the first responder belongs to title view
    UIView *keyboardView = titleView.inputAccessoryView.superview;
    if (!keyboardView)
    {
        // Check whether the first responder is the input tool bar text composer
        keyboardView = inputToolbarView.inputAccessoryView.superview;
    }
    
    // Report the keyboard view in order to track keyboard frame changes
    self.keyboardView = keyboardView;
}

- (void)setKeyboardHeight:(CGFloat)keyboardHeight
{
    // Deduce the bottom constraint for the input toolbar view (Don't forget the potential tabBar)
    CGFloat inputToolbarViewBottomConst = keyboardHeight - self.bottomLayoutGuide.length;
    // Check whether the keyboard is over the tabBar
    if (inputToolbarViewBottomConst < 0)
    {
        inputToolbarViewBottomConst = 0;
    }
    
    // Update constraints
    _roomInputToolbarContainerBottomConstraint.constant = inputToolbarViewBottomConst;
    _bubblesTableViewBottomConstraint.constant = inputToolbarViewBottomConst + _roomInputToolbarContainerHeightConstraint.constant;
    
    // Force layout immediately to take into account new constraint
    [self.view layoutIfNeeded];
    
    // Compute the visible area (tableview + toolbar) at the end of animation
    CGFloat visibleArea = self.view.frame.size.height - _bubblesTableView.contentInset.top - keyboardHeight;
    // Deduce max height of the message text input by considering the minimum height of the table view.
    inputToolbarView.maxHeight = visibleArea - MXKROOMVIEWCONTROLLER_MESSAGES_TABLE_MINIMUM_HEIGHT;
    
    // Scroll the tableview content when a new keyboard is presented.
    if (!super.keyboardHeight && keyboardHeight)
    {
        [self scrollBubblesTableViewToBottomAnimated:NO];
    }
    
    super.keyboardHeight = keyboardHeight;
}

- (void)destroy
{
    if (kMXSessionWillLeaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXSessionWillLeaveRoomNotificationObserver];
        kMXSessionWillLeaveRoomNotificationObserver = nil;
    }
    
    if (UIMenuControllerDidHideMenuNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIMenuControllerDidHideMenuNotificationObserver];
        UIMenuControllerDidHideMenuNotificationObserver = nil;
    }
    
    if (onAttachmentDownloadEndObs)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadEndObs];
        onAttachmentDownloadEndObs = nil;
    }
    
    if (onAttachmentDownloadFailureObs)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadFailureObs];
        onAttachmentDownloadFailureObs = nil;
    }
    
    if (documentInteractionController)
    {
        [documentInteractionController dismissPreviewAnimated:NO];
        [documentInteractionController dismissMenuAnimated:NO];
        documentInteractionController = nil;
    }
    
    if (documentSymbolicLinkPath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
        documentSymbolicLinkPath = nil;
    }
    
    [self dismissTemporarySubViews];
    
    _bubblesTableView.dataSource = nil;
    _bubblesTableView.delegate = nil;
    _bubblesTableView = nil;
    
    roomDataSource.delegate = nil;
    roomDataSource = nil;
    
    if (titleView)
    {
        [titleView removeFromSuperview];
        [titleView destroy];
        titleView = nil;
    }
    
    if (inputToolbarView)
    {
        [inputToolbarView removeFromSuperview];
        [inputToolbarView destroy];
        inputToolbarView = nil;
    }
    
    [typingTimer invalidate];
    typingTimer = nil;
    
    if (joinRoomRequest)
    {
        [joinRoomRequest cancel];
        joinRoomRequest = nil;
    }
    
    [super destroy];
}

#pragma mark -

- (void)configureView
{
    [self dismissTemporarySubViews];
    
    // Set up table delegates
    _bubblesTableView.delegate = self;
    _bubblesTableView.dataSource = roomDataSource;
    
    // Set up classes to use for cells
    [_bubblesTableView registerClass:[roomDataSource cellViewClassForCellIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier] forCellReuseIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier];
    [_bubblesTableView registerClass:[roomDataSource cellViewClassForCellIdentifier:kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier] forCellReuseIdentifier:kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier];
    [_bubblesTableView registerClass:[roomDataSource cellViewClassForCellIdentifier:kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier] forCellReuseIdentifier:kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier];
    [_bubblesTableView registerClass:[roomDataSource cellViewClassForCellIdentifier:kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier] forCellReuseIdentifier:kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier];
    
    // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
    kMXSessionWillLeaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Check whether the user will leave the current room
        if (notif.object == self.mainSession)
        {
            NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
            if (roomId && [roomId isEqualToString:roomDataSource.roomId])
            {
                // Update view controller appearance
                [self leaveRoomOnEvent:notif.userInfo[kMXSessionNotificationEventKey]];
            }
        }
    }];
}

- (void)updateMessageTextViewFrame
{
    if (!self.keyboardView)
    {
        // Compute the visible area (tableview + toolbar)
        CGFloat visibleArea = self.view.frame.size.height - _bubblesTableView.contentInset.top - self.keyboardView.frame.size.height;
        // Deduce max height of the message text input by considering the minimum height of the table view.
        inputToolbarView.maxHeight = visibleArea - MXKROOMVIEWCONTROLLER_MESSAGES_TABLE_MINIMUM_HEIGHT;
    }
}

- (void)onRoomDataSourceReady
{
    // If the user is only invited, auto-join the room
    if (roomDataSource.room.state.membership == MXMembershipInvite)
    {
        // Check whether a join request is not already running
        if (!joinRoomRequest)
        {
            [self startActivityIndicator];
            joinRoomRequest = [roomDataSource.room join:^{
                
                joinRoomRequest = nil;
                [self stopActivityIndicator];
                
                [self triggerInitialBackPagination];
            } failure:^(NSError *error) {
                
                NSLog(@"[MXKRoomDataSource] Failed to join room (%@): %@", roomDataSource.room.state.displayname, error);
                
                joinRoomRequest = nil;
                [self stopActivityIndicator];
                
                // Show the error to the end user
                __weak typeof(self) weakSelf = self;
                currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"error"]
                                                       message:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"room_error_join_failed"], roomDataSource.room.state.displayname]
                                                         style:MXKAlertStyleAlert];
                currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                                                  {
                                                      typeof(self) self = weakSelf;
                                                      self->currentAlert = nil;
                                                  }];
                
                [currentAlert showInViewController:self];
            }];
        }
    }
    else
    {
        [self triggerInitialBackPagination];
    }
}

- (BOOL)isBubblesTableScrollViewAtTheBottom
{
    // Check whether the most recent message is visible.
    // Compute the max vertical position visible according to contentOffset
    CGFloat maxPositionY = _bubblesTableView.contentOffset.y + (_bubblesTableView.frame.size.height - _bubblesTableView.contentInset.bottom);
    // Be a bit less retrictive, consider the table view at the bottom even if the most recent message is partially hidden
    maxPositionY += 30;
    BOOL isScrolledToBottom = (maxPositionY >= _bubblesTableView.contentSize.height);
    
    // Consider the table view at the bottom if a scrolling to bottom is in progress too
    return (isScrolledToBottom || isScrollingToBottom);
}

- (void)scrollBubblesTableViewToBottomAnimated:(BOOL)animated
{
    if (_bubblesTableView.contentSize.height)
    {
        CGFloat visibleHeight = _bubblesTableView.frame.size.height - _bubblesTableView.contentInset.top - _bubblesTableView.contentInset.bottom;
        if (visibleHeight < _bubblesTableView.contentSize.height)
        {
            CGFloat wantedOffsetY = _bubblesTableView.contentSize.height - visibleHeight - _bubblesTableView.contentInset.top;
            CGFloat currentOffsetY = _bubblesTableView.contentOffset.y;
            if (wantedOffsetY != currentOffsetY)
            {
                isScrollingToBottom = YES;
                [_bubblesTableView setContentOffset:CGPointMake(0, wantedOffsetY) animated:animated];
            }
        }
    }
}

#pragma mark -

- (void)dismissTemporarySubViews
{
    [self dismissKeyboard];
    
    [self hideAttachmentView];
    
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    if (eventDetailsView)
    {
        [eventDetailsView removeFromSuperview];
        eventDetailsView = nil;
    }
    
    if (_leftRoomReasonLabel)
    {
        [_leftRoomReasonLabel removeFromSuperview];
        _leftRoomReasonLabel = nil;
        _bubblesTableView.tableHeaderView = nil;
    }
    
    // Dispose potential keyboard view
    self.keyboardView = nil;
}

#pragma mark - Public API

- (void)displayRoom:(MXKRoomDataSource *)dataSource
{
    if (roomDataSource)
    {
        roomDataSource = nil;
        [self removeMatrixSession:self.mainSession];
    }
    
    if (dataSource)
    {
        roomDataSource = dataSource;
        roomDataSource.delegate = self;
        
        // Report the matrix session at view controller level to update UI according to session state
        [self addMatrixSession:roomDataSource.mxSession];
        
        if (_bubblesTableView)
        {
            [self configureView];
        }
        
        // When ready, do the initial back pagination
        if (roomDataSource.state == MXKDataSourceStateReady)
        {
            [self onRoomDataSourceReady];
        }
    }
    
    [self updateViewControllerAppearanceOnRoomDataSourceState];
}

- (void)updateViewControllerAppearanceOnRoomDataSourceState
{
    // Update UI by considering dataSource state
    if (roomDataSource && roomDataSource.state == MXKDataSourceStateReady)
    {
        [self stopActivityIndicator];
        
        if (titleView)
        {
            titleView.mxRoom = roomDataSource.room;
            titleView.editable = YES;
            titleView.hidden = NO;
        }
        else
        {
            // set default title
            self.navigationItem.title = roomDataSource.room.state.displayname;
        }
        
        // Show input tool bar
        inputToolbarView.hidden = NO;
    }
    else
    {
        // Update the title except if the room has just been left
        if (!_leftRoomReasonLabel)
        {
            if (roomDataSource && roomDataSource.state == MXKDataSourceStatePreparing)
            {
                if (titleView)
                {
                    titleView.mxRoom = roomDataSource.room;
                    titleView.hidden = (!titleView.mxRoom);
                }
                else
                {
                    self.navigationItem.title = roomDataSource.room.state.displayname;
                }
            }
            else
            {
                if (titleView)
                {
                    titleView.mxRoom = nil;
                    titleView.hidden = NO;
                }
                else
                {
                    self.navigationItem.title = nil;
                }
            }
        }
        titleView.editable = NO;
        
        // Hide input tool bar
        inputToolbarView.hidden = YES;
    }
    
    // Finalize room title refresh
    [titleView refreshDisplay];
}

- (void)leaveRoomOnEvent:(MXEvent*)event
{
    [self dismissTemporarySubViews];
    
    NSString *reason = nil;
    if (event)
    {
        MXKEventFormatterError error;
        reason = [roomDataSource.eventFormatter stringFromEvent:event withRoomState:roomDataSource.room.state error:&error];
        if (error != MXKEventFormatterErrorNone)
        {
            reason = nil;
        }
    }
    
    if (!reason.length)
    {
        reason = [NSBundle mxk_localizedStringForKey:@"room_left"];
    }
    
    
    _bubblesTableView.dataSource = nil;
    _bubblesTableView.delegate = nil;
    
    roomDataSource.delegate = nil;
    roomDataSource = nil;
    
    // Add reason label
    _leftRoomReasonLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, self.view.frame.size.width - 16, 44)];
    _leftRoomReasonLabel.text = reason;
    _leftRoomReasonLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bubblesTableView.tableHeaderView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 36)];
    [_bubblesTableView.tableHeaderView addSubview:_leftRoomReasonLabel];
    [_bubblesTableView reloadData];
    
    [self updateViewControllerAppearanceOnRoomDataSourceState];
}

- (void)setRoomTitleViewClass:(Class)roomTitleViewClass
{
    // Sanity check: accept only MXKRoomTitleView classes or sub-classes
    NSParameterAssert([roomTitleViewClass isSubclassOfClass:MXKRoomTitleView.class]);
    
    if (!_roomTitleViewContainer)
    {
        NSLog(@"[MXKRoomVC] Set roomTitleViewClass failed: container is missing");
        return;
    }
    
    [self dismissKeyboard];
    
    // Remove potential title view
    if (titleView)
    {
        if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)])
        {
            [NSLayoutConstraint deactivateConstraints:titleView.constraints];
        }
        else
        {
            [_roomTitleViewContainer removeConstraints:titleView.constraints];
        }
        [titleView removeFromSuperview];
        [titleView destroy];
    }
    
    titleView = [roomTitleViewClass roomTitleView];
    
    titleView.delegate = self;
    
    // Add the title view and define edge constraints
    [_roomTitleViewContainer addSubview:titleView];
    [_roomTitleViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomTitleViewContainer
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:titleView
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    [_roomTitleViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomTitleViewContainer
                                                                        attribute:NSLayoutAttributeTop
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:titleView
                                                                        attribute:NSLayoutAttributeTop
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    [_roomTitleViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomTitleViewContainer
                                                                        attribute:NSLayoutAttributeLeading
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:titleView
                                                                        attribute:NSLayoutAttributeLeading
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    [_roomTitleViewContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomTitleViewContainer
                                                                        attribute:NSLayoutAttributeTrailing
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:titleView
                                                                        attribute:NSLayoutAttributeTrailing
                                                                       multiplier:1.0f
                                                                         constant:0.0f]];
    [_roomTitleViewContainer setNeedsUpdateConstraints];
}

- (void)setRoomInputToolbarViewClass:(Class)roomInputToolbarViewClass
{
    // Sanity check: accept only MXKRoomInputToolbarView classes or sub-classes
    NSParameterAssert([roomInputToolbarViewClass isSubclassOfClass:MXKRoomInputToolbarView.class]);
    
    if (!_roomInputToolbarContainer)
    {
        NSLog(@"[MXKRoomVC] Set roomInputToolbarViewClass failed: container is missing");
        return;
    }
    
    [self dismissKeyboard];
    
    // Remove potential toolbar
    if (inputToolbarView)
    {
        if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)])
        {
            [NSLayoutConstraint deactivateConstraints:inputToolbarView.constraints];
        }
        else
        {
            [_roomInputToolbarContainer removeConstraints:inputToolbarView.constraints];
        }
        [inputToolbarView removeFromSuperview];
        [inputToolbarView destroy];
    }
    
    inputToolbarView = [roomInputToolbarViewClass roomInputToolbarView];
    
    inputToolbarView.delegate = self;
    
    // Add the input toolbar view and define edge constraints
    [_roomInputToolbarContainer addSubview:inputToolbarView];
    [_roomInputToolbarContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomInputToolbarContainer
                                                                           attribute:NSLayoutAttributeBottom
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:inputToolbarView
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1.0f
                                                                            constant:0.0f]];
    [_roomInputToolbarContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomInputToolbarContainer
                                                                           attribute:NSLayoutAttributeTop
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:inputToolbarView
                                                                           attribute:NSLayoutAttributeTop
                                                                          multiplier:1.0f
                                                                            constant:0.0f]];
    [_roomInputToolbarContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomInputToolbarContainer
                                                                           attribute:NSLayoutAttributeLeading
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:inputToolbarView
                                                                           attribute:NSLayoutAttributeLeading
                                                                          multiplier:1.0f
                                                                            constant:0.0f]];
    [_roomInputToolbarContainer addConstraint:[NSLayoutConstraint constraintWithItem:_roomInputToolbarContainer
                                                                           attribute:NSLayoutAttributeTrailing
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:inputToolbarView
                                                                           attribute:NSLayoutAttributeTrailing
                                                                          multiplier:1.0f
                                                                            constant:0.0f]];
    [_roomInputToolbarContainer setNeedsUpdateConstraints];
}

- (BOOL)isIRCStyleCommand:(NSString*)string
{
    // Check whether the provided text may be an IRC-style command
    if ([string hasPrefix:@"/"] == NO || [string hasPrefix:@"//"] == YES)
    {
        return NO;
    }
    
    // Parse command line
    NSArray *components = [string componentsSeparatedByString:@" "];
    NSString *cmd = [components objectAtIndex:0];
    NSUInteger index = 1;
    
    if ([cmd isEqualToString:kCmdEmote])
    {
        // send message as an emote
        [self sendTextMessage:string];
    }
    else if ([string hasPrefix:kCmdChangeDisplayName])
    {
        // Change display name
        NSString *displayName = [string substringFromIndex:kCmdChangeDisplayName.length + 1];
        // Remove white space from both ends
        displayName = [displayName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if (displayName.length)
        {
            [roomDataSource.mxSession.matrixRestClient setDisplayName:displayName success:^{
                
            } failure:^(NSError *error) {
                
                NSLog(@"[MXKRoomVC] Set displayName failed: %@", error);
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                
            }];
        }
        else
        {
            // Display cmd usage in text input as placeholder
            inputToolbarView.placeholder = @"Usage: /nick <display_name>";
        }
    }
    else if ([string hasPrefix:kCmdJoinRoom])
    {
        // Join a room
        NSString *roomAlias = [string substringFromIndex:kCmdJoinRoom.length + 1];
        // Remove white space from both ends
        roomAlias = [roomAlias stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Check
        if (roomAlias.length)
        {
            [roomDataSource.mxSession joinRoom:roomAlias success:^(MXRoom *room) {
                // Do nothing by default when we succeed to join the room
            } failure:^(NSError *error) {
                
                NSLog(@"[MXKRoomVC] Join roomAlias (%@) failed: %@", roomAlias, error);
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                
            }];
        }
        else
        {
            // Display cmd usage in text input as placeholder
            inputToolbarView.placeholder = @"Usage: /join <room_alias>";
        }
    }
    else
    {
        // Retrieve userId
        NSString *userId = nil;
        while (index < components.count)
        {
            userId = [components objectAtIndex:index++];
            if (userId.length)
            {
                // done
                break;
            }
            // reset
            userId = nil;
        }
        
        if ([cmd isEqualToString:kCmdKickUser])
        {
            if (userId)
            {
                // Retrieve potential reason
                NSString *reason = nil;
                while (index < components.count)
                {
                    if (reason)
                    {
                        reason = [NSString stringWithFormat:@"%@ %@", reason, [components objectAtIndex:index++]];
                    }
                    else
                    {
                        reason = [components objectAtIndex:index++];
                    }
                }
                // Kick the user
                [roomDataSource.room kickUser:userId reason:reason success:^{
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[MXKRoomVC] Kick user (%@) failed: %@", userId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
            }
            else
            {
                // Display cmd usage in text input as placeholder
                inputToolbarView.placeholder = @"Usage: /kick <userId> [<reason>]";
            }
        }
        else if ([cmd isEqualToString:kCmdBanUser])
        {
            if (userId)
            {
                // Retrieve potential reason
                NSString *reason = nil;
                while (index < components.count)
                {
                    if (reason)
                    {
                        reason = [NSString stringWithFormat:@"%@ %@", reason, [components objectAtIndex:index++]];
                    }
                    else
                    {
                        reason = [components objectAtIndex:index++];
                    }
                }
                // Ban the user
                [roomDataSource.room banUser:userId reason:reason success:^{
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[MXKRoomVC] Ban user (%@) failed: %@", userId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
            }
            else
            {
                // Display cmd usage in text input as placeholder
                inputToolbarView.placeholder = @"Usage: /ban <userId> [<reason>]";
            }
        }
        else if ([cmd isEqualToString:kCmdUnbanUser])
        {
            if (userId)
            {
                // Unban the user
                [roomDataSource.room unbanUser:userId success:^{
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[MXKRoomVC] Unban user (%@) failed: %@", userId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
            }
            else
            {
                // Display cmd usage in text input as placeholder
                inputToolbarView.placeholder = @"Usage: /unban <userId>";
            }
        }
        else if ([cmd isEqualToString:kCmdSetUserPowerLevel])
        {
            // Retrieve power level
            NSString *powerLevel = nil;
            while (index < components.count)
            {
                powerLevel = [components objectAtIndex:index++];
                if (powerLevel.length)
                {
                    // done
                    break;
                }
                // reset
                powerLevel = nil;
            }
            // Set power level
            if (userId && powerLevel)
            {
                // Set user power level
                [roomDataSource.room setPowerLevelOfUserWithUserID:userId powerLevel:[powerLevel integerValue] success:^{
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[MXKRoomVC] Set user power (%@) failed: %@", userId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
            }
            else
            {
                // Display cmd usage in text input as placeholder
                inputToolbarView.placeholder = @"Usage: /op <userId> <power level>";
            }
        }
        else if ([cmd isEqualToString:kCmdResetUserPowerLevel])
        {
            if (userId)
            {
                // Reset user power level
                [roomDataSource.room setPowerLevelOfUserWithUserID:userId powerLevel:0 success:^{
                    
                } failure:^(NSError *error) {
                    
                    NSLog(@"[MXKRoomVC] Reset user power (%@) failed: %@", userId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
            }
            else
            {
                // Display cmd usage in text input as placeholder
                inputToolbarView.placeholder = @"Usage: /deop <userId>";
            }
        }
        else
        {
            NSLog(@"[MXKRoomVC] Unrecognised IRC-style command: %@", string);
//            inputToolbarView.placeholder = [NSString stringWithFormat:@"Unrecognised IRC-style command: %@", cmd];
            return NO;
        }
    }
    return YES;
}

- (void)dismissKeyboard
{
    [titleView dismissKeyboard];
    [inputToolbarView dismissKeyboard];
}

#pragma mark - activity indicator

- (void)stopActivityIndicator
{
    // Keep the loading wheel displayed while we are joining the room
    if (joinRoomRequest)
    {
        return;
    }
    
    // Check internal processes before stopping the loading wheel
    if (isBackPaginationInProgress)
    {
        // Keep activity indicator running
        return;
    }
    
    // Leave super decide
    [super stopActivityIndicator];
}

#pragma mark - Back pagination

- (void)triggerInitialBackPagination
{
    // Trigger back pagination to fill all the screen
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    CGRect frame = window.rootViewController.view.bounds;
    
    isBackPaginationInProgress = YES;
    [self startActivityIndicator];
    [roomDataSource paginateBackMessagesToFillRect:frame
                                           success:^{
                                               
                                               // Reload table
                                               isBackPaginationInProgress = NO;
                                               [self reloadBubblesTable];
                                               [self stopActivityIndicator];
                                               
                                           }
                                           failure:^(NSError *error) {
                                               
                                               // Reload table
                                               isBackPaginationInProgress = NO;
                                               [self reloadBubblesTable];
                                               [self stopActivityIndicator];
                                               
                                           }];
}

- (void)triggerBackPagination
{
    // Paginate only if possible
    if (NO == roomDataSource.room.canPaginate)
    {
        return;
    }
    
    // Store the current height of the first bubble (if any)
    backPaginationSavedFirstBubbleHeight = 0;
    backPaginationSavedBubblesNb = [roomDataSource tableView:_bubblesTableView numberOfRowsInSection:0];
    if (backPaginationSavedBubblesNb)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        backPaginationSavedFirstBubbleHeight = [self tableView:_bubblesTableView heightForRowAtIndexPath:indexPath];
    }
    isBackPaginationInProgress = YES;
    [self startActivityIndicator];
    
    // Trigger back pagination
    [roomDataSource paginateBackMessages:10 success:^{
        
        // We will scroll to bottom if the displayed content does not reach the bottom (after adding back pagination)
        BOOL shouldScrollToBottom = NO;
        CGFloat maxPositionY = self.bubblesTableView.contentOffset.y + (self.bubblesTableView.frame.size.height - self.bubblesTableView.contentInset.bottom);
        // Compute the height of the blank part at the bottom
        if (maxPositionY > self.bubblesTableView.contentSize.height)
        {
            CGFloat blankAreaHeight = maxPositionY - self.bubblesTableView.contentSize.height;
            // Scroll to bottom if this blank area is greater than max scrolling offet
            shouldScrollToBottom = (blankAreaHeight >= MXKROOMVIEWCONTROLLER_BACK_PAGINATION_MAX_SCROLLING_OFFSET);
        }
        
        CGFloat verticalOffset = 0;
        if (shouldScrollToBottom == NO)
        {
            NSInteger addedBubblesNb = [roomDataSource tableView:_bubblesTableView numberOfRowsInSection:0] - backPaginationSavedBubblesNb;
            if (addedBubblesNb >= 0)
            {
                
                // We will adjust the vertical offset in order to make visible only a few part of added messages (at the top of the table)
                NSIndexPath *indexPath;
                // Compute the cumulative height of the added messages
                for (NSUInteger index = 0; index < addedBubblesNb; index++)
                {
                    indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                    verticalOffset += [self tableView:_bubblesTableView heightForRowAtIndexPath:indexPath];
                }
                
                // Add delta of the height of the first existing message
                indexPath = [NSIndexPath indexPathForRow:addedBubblesNb inSection:0];
                verticalOffset += ([self tableView:_bubblesTableView heightForRowAtIndexPath:indexPath] - backPaginationSavedFirstBubbleHeight);
                
                // Deduce the vertical offset from this height
                verticalOffset -= MXKROOMVIEWCONTROLLER_BACK_PAGINATION_MAX_SCROLLING_OFFSET;
            }
        }
        
        // Adjust vertical content offset
        if (shouldScrollToBottom)
        {
            [self scrollBubblesTableViewToBottomAnimated:NO];
        }
        else if (verticalOffset > 0)
        {
            // Adjust vertical offset in order to limit scrolling down
            CGPoint contentOffset = self.bubblesTableView.contentOffset;
            contentOffset.y = verticalOffset - self.bubblesTableView.contentInset.top;
            [self.bubblesTableView setContentOffset:contentOffset animated:NO];
        }
        
        // Reload table
        isBackPaginationInProgress = NO;
        [self reloadBubblesTable];
        [self stopActivityIndicator];
        
    }
                                 failure:^(NSError *error)
    {
        // Reload table
        isBackPaginationInProgress = NO;
        [self reloadBubblesTable];
        [self stopActivityIndicator];
    }];
}

#pragma mark - Post messages

- (void)sendTextMessage:(NSString*)msgTxt
{
    // Let the datasource send it and manage the local echo
    [roomDataSource sendTextMessage:msgTxt success:nil failure:^(NSError *error)
    {
        // Just log the error. The message will be displayed in red in the room history
        NSLog(@"[MXKRoomViewController] sendTextMessage failed. Error:%@", error);
    }];
}

# pragma mark - Event handling

- (void)showEventDetails:(MXEvent *)event
{
    [self dismissKeyboard];
    
    // Remove potential existing view
    if (eventDetailsView)
    {
        [eventDetailsView removeFromSuperview];
    }
    eventDetailsView = [[MXKEventDetailsView alloc] initWithEvent:event andMatrixSession:roomDataSource.mxSession];
    
    // Add shadow on event details view
    eventDetailsView.layer.cornerRadius = 5;
    eventDetailsView.layer.shadowOffset = CGSizeMake(0, 1);
    eventDetailsView.layer.shadowOpacity = 0.5f;
    
    // Add the view and define edge constraints
    [self.view addSubview:eventDetailsView];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:eventDetailsView
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.topLayoutGuide
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:10.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:eventDetailsView
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.bottomLayoutGuide
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0f
                                                           constant:-10.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:eventDetailsView
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1.0f
                                                           constant:-10.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:eventDetailsView
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1.0f
                                                           constant:10.0f]];
    [self.view setNeedsUpdateConstraints];
}

- (void)promptUserToResendEvent:(NSString *)eventId
{
    MXEvent *event = [roomDataSource eventWithEventId:eventId];
    
    NSLog(@"[MXKRoomViewController] promptUserToResendEvent: %@", event);
    
    if (event && event.eventType == MXEventTypeRoomMessage)
    {
        NSString *msgtype = event.content[@"msgtype"];
        
        NSString* textMessage;
        if ([msgtype isEqualToString:kMXMessageTypeText])
        {
            textMessage = event.content[@"body"];
        }
        
        // Show a confirmation popup to the end user
        if (currentAlert)
        {
            [currentAlert dismiss:NO];
            currentAlert = nil;
        }
        
        __weak typeof(self) weakSelf = self;
        currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"resend_message"]
                                               message:textMessage
                                                 style:MXKAlertStyleAlert];
        currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
        }];
        
        [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
            
            // Let the datasource resend. It will manage local echo, etc.
            [self->roomDataSource resendEventWithEventId:eventId success:nil failure:nil];
        }];
        
        [currentAlert showInViewController:self];
    }
}

#pragma mark - bubbles table

- (void)reloadBubblesTable
{
    // We will scroll to bottom if the bottom of the table is currently visible
    BOOL shouldScrollToBottom = (shouldScrollToBottomOnTableRefresh || [self isBubblesTableScrollViewAtTheBottom]);
    
    // For now, do a simple full reload
    [_bubblesTableView reloadData];
    
    if (shouldScrollToBottom)
    {
        // Scroll to the bottom
        [self scrollBubblesTableViewToBottomAnimated:NO];
    }
}

#pragma mark - MXKDataSourceDelegate
- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    if (isBackPaginationInProgress)
    {
        // table will be updated at the end of pagination.
        return;
    }
    
    [self reloadBubblesTable];
}

- (void)dataSource:(MXKDataSource *)dataSource didStateChange:(MXKDataSourceState)state
{
    [self updateViewControllerAppearanceOnRoomDataSourceState];
    
    if (state == MXKDataSourceStateReady)
    {
        [self onRoomDataSourceReady];
    }
}

- (void)dataSource:(MXKDataSource *)dataSource didRecognizeAction:(NSString *)actionIdentifier inCell:(id<MXKCellRendering>)cell userInfo:(NSDictionary *)userInfo
{
    NSLog(@"Gesture %@ has been recognized in %@. UserInfo: %@", actionIdentifier, cell, userInfo);
    
    if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnAvatarView])
    {
        NSLog(@"    -> Avatar of %@ has been tapped", userInfo[kMXKRoomBubbleCellUserIdKey]);
    }
    else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnDateTimeContainer])
    {
        roomDataSource.showBubblesDateTime = !roomDataSource.showBubblesDateTime;
        NSLog(@"    -> Turn %@ cells date", roomDataSource.showBubblesDateTime ? @"ON" : @"OFF");
        
        [self reloadBubblesTable];
    }
    else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnAttachmentView])
    {
        [self showAttachmentInCell:cell];
    }
    else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellLongPressOnProgressView])
    {
        MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
        
        // Check if there is a download in progress, then offer to cancel it
        NSString *cacheFilePath = roomBubbleTableViewCell.bubbleData.attachmentCacheFilePath;
        if ([MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath])
        {
            if (currentAlert)
            {
                [currentAlert dismiss:NO];
                currentAlert = nil;
            }
            
            __weak __typeof(self) weakSelf = self;
            currentAlert = [[MXKAlert alloc] initWithTitle:nil message:[NSBundle mxk_localizedStringForKey:@"attachment_cancel_download"] style:MXKAlertStyleAlert];
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
            }];
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Get again the loader
                MXKMediaLoader *loader = [MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
                if (loader)
                {
                    [loader cancel];
                }
                
                // Hide the progress animation
                roomBubbleTableViewCell.progressView.hidden = YES;
            }];
            
            [currentAlert showInViewController:self];
        }
        else
        {
            // Check if there is an upload in progress, then offer to cancel it
            // Upload id is stored in attachment url (nasty trick)
            NSString *uploadId = roomBubbleTableViewCell.bubbleData.attachmentURL;
            if ([MXKMediaManager existingUploaderWithId:uploadId])
            {
                if (currentAlert)
                {
                    [currentAlert dismiss:NO];
                    currentAlert = nil;
                }
                
                __weak __typeof(self) weakSelf = self;
                currentAlert = [[MXKAlert alloc] initWithTitle:nil message:[NSBundle mxk_localizedStringForKey:@"attachment_cancel_upload"] style:MXKAlertStyleAlert];
                currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                }];
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Get again the loader
                    MXKMediaLoader *loader = [MXKMediaManager existingUploaderWithId:uploadId];
                    if (loader)
                    {
                        [loader cancel];
                    }
                    
                    // Hide the progress animation
                    roomBubbleTableViewCell.progressView.hidden = YES;
                }];
                
                [currentAlert showInViewController:self];
            }
        }
    }
    else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellLongPressOnEvent])
    {
        [self dismissKeyboard];
        
        MXEvent *selectedEvent = userInfo[kMXKRoomBubbleCellEventKey];
        MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
        
        if (selectedEvent)
        {
            if (currentAlert)
            {
                [currentAlert dismiss:NO];
                currentAlert = nil;
                
                // Cancel potential text selection in other bubbles
                for (MXKRoomBubbleTableViewCell *bubble in self.bubblesTableView.visibleCells)
                {
                    [bubble highlightTextMessageForEvent:nil];
                }
            }
            
            __weak __typeof(self) weakSelf = self;
            currentAlert = [[MXKAlert alloc] initWithTitle:nil message:nil style:MXKAlertStyleActionSheet];
            
            // Add actions for a failed event
            if (selectedEvent.mxkState == MXKEventStateSendingFailed)
            {
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"resend"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Let the datasource resend. It will manage local echo, etc.
                    [strongSelf.roomDataSource resendEventWithEventId:selectedEvent.eventId success:nil failure:nil];
                }];
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"delete"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    [strongSelf.roomDataSource removeEventWithEventId:selectedEvent.eventId];
                }];
            }
            
            // Add actions for text message
            if (!selectedEvent.isMediaAttachment)
            {
                // Highlight the select event
                [roomBubbleTableViewCell highlightTextMessageForEvent:selectedEvent.eventId];
                
                // Retrieved data related to the selected event
                NSArray *components = roomBubbleTableViewCell.bubbleData.bubbleComponents;
                MXKRoomBubbleComponent *selectedComponent;
                for (selectedComponent in components)
                {
                    if ([selectedComponent.event.eventId isEqualToString:selectedEvent.eventId])
                    {
                        break;
                    }
                    selectedComponent = nil;
                }
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"copy"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Cancel event highlighting
                    [roomBubbleTableViewCell highlightTextMessageForEvent:nil];
                    
                    [[UIPasteboard generalPasteboard] setString:selectedComponent.textMessage];
                }];
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"share"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Cancel event highlighting
                    [roomBubbleTableViewCell highlightTextMessageForEvent:nil];
                    
                    NSArray *activityItems = [NSArray arrayWithObjects:selectedComponent.textMessage, nil];
                    
                    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
                    activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                    
                    if (activityViewController)
                    {
                        [strongSelf presentViewController:activityViewController animated:YES completion:nil];
                    }
                }];
                
                if (components.count > 1)
                {
                    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"select_all"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        strongSelf->currentAlert = nil;
                        
                        [strongSelf selectAllTextMessageInCell:cell];
                    }];
                }
            }
            else // Add action for medias
            {
                NSString *msgtype = selectedEvent.content[@"msgtype"];
                
                if ([msgtype isEqualToString:kMXMessageTypeImage] || [msgtype isEqualToString:kMXMessageTypeVideo])
                {
                    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"save"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        strongSelf->currentAlert = nil;
                        
                        [strongSelf downloadAttachmentInCell:cell success:^(NSString *cacheFilePath) {
                            
                            BOOL isImage = [msgtype isEqualToString:kMXMessageTypeImage];
                            NSURL* url = [NSURL fileURLWithPath:cacheFilePath];
                            
                            [strongSelf startActivityIndicator];
                            [MXKMediaManager saveMediaToPhotosLibrary:url
                                                              isImage:isImage
                                                              success:^() {
                                                                  
                                                                  __strong __typeof(weakSelf)strongSelf = weakSelf;
                                                                  [strongSelf stopActivityIndicator];
                                                                  
                                                              } failure:^(NSError *error) {
                                                                  
                                                                  __strong __typeof(weakSelf)strongSelf = weakSelf;
                                                                  [strongSelf stopActivityIndicator];
                                                                  
                                                                  // Notify MatrixKit user
                                                                  [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                                                  
                                                              }];
                        } failure:nil];
                    }];
                }
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"share"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    [strongSelf downloadAttachmentInCell:cell success:^(NSString *cacheFilePath) {
                        
                        NSURL *fileUrl;
                        
                        // The original attachment body (if any) is reported in bubble text message
                        NSString *attachmentBody = roomBubbleTableViewCell.bubbleData.textMessage;
                        if ([attachmentBody pathExtension].length)
                        {
                            // Create a symbolic link to the cached file to keep its original name
                            strongSelf->documentSymbolicLinkPath = [[MXKMediaManager getCachePath] stringByAppendingPathComponent:attachmentBody];
                            
                            [[NSFileManager defaultManager] removeItemAtPath:strongSelf->documentSymbolicLinkPath error:nil];
                            if ([[NSFileManager defaultManager] createSymbolicLinkAtPath:strongSelf->documentSymbolicLinkPath withDestinationPath:cacheFilePath error:nil])
                            {
                                fileUrl = [NSURL fileURLWithPath:strongSelf->documentSymbolicLinkPath];
                            }
                        }
                        
                        if (!fileUrl)
                        {
                            // Use the cached file by default
                            fileUrl = [NSURL fileURLWithPath:cacheFilePath];
                        }
                        
                        strongSelf->documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileUrl];
                        [strongSelf->documentInteractionController setDelegate:strongSelf];
                        
                        if (![strongSelf->documentInteractionController presentOptionsMenuFromRect:strongSelf.view.frame inView:strongSelf.view animated:YES])
                        {
                            strongSelf->documentInteractionController = nil;
                            if (strongSelf->documentSymbolicLinkPath)
                            {
                                [[NSFileManager defaultManager] removeItemAtPath:strongSelf->documentSymbolicLinkPath error:nil];
                                strongSelf->documentSymbolicLinkPath = nil;
                            }
                        }
                    } failure:nil];
                }];
            }
            
            // Check status of the selected event
            if (selectedEvent.mxkState == MXKEventStateUploading)
            {
                // Upload id is stored in attachment url (nasty trick)
                NSString *uploadId = roomBubbleTableViewCell.bubbleData.attachmentURL;
                if ([MXKMediaManager existingUploaderWithId:uploadId])
                {
                    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel_upload"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        strongSelf->currentAlert = nil;
                        
                        // Get again the loader
                        MXKMediaLoader *loader = [MXKMediaManager existingUploaderWithId:uploadId];
                        if (loader)
                        {
                            [loader cancel];
                        }
                        // Hide the progress animation
                        roomBubbleTableViewCell.progressView.hidden = YES;
                    }];
                }
            }
            else if (selectedEvent.mxkState != MXKEventStateSending && selectedEvent.mxkState != MXKEventStateSendingFailed)
            {
                // Check whether download is in progress
                if (selectedEvent.isMediaAttachment)
                {
                    NSString *cacheFilePath = roomBubbleTableViewCell.bubbleData.attachmentCacheFilePath;
                    if ([MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath])
                    {
                        [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel_download"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            strongSelf->currentAlert = nil;
                            
                            // Get again the loader
                            MXKMediaLoader *loader = [MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
                            if (loader)
                            {
                                [loader cancel];
                            }
                            // Hide the progress animation
                            roomBubbleTableViewCell.progressView.hidden = YES;
                        }];
                    }
                }
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"show_details"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Cancel event highlighting (if any)
                    [roomBubbleTableViewCell highlightTextMessageForEvent:nil];
                    
                    // Display event details
                    [strongSelf showEventDetails:selectedEvent];
                }];
            }
            
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Cancel event highlighting (if any)
                [roomBubbleTableViewCell highlightTextMessageForEvent:nil];
            }];
            
            // Do not display empty action sheet
            if (currentAlert.cancelButtonIndex)
            {
                currentAlert.sourceView = roomBubbleTableViewCell;
                [currentAlert showInViewController:self];
            }
            else
            {
                currentAlert = nil;
            }
        }
    }
    else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellUnsentButtonPressed])
    {
        MXEvent *selectedEvent = userInfo[kMXKRoomBubbleCellEventKey];
        if (selectedEvent)
        {
            // The user may want to resend it
            [self promptUserToResendEvent:selectedEvent.eventId];
        }
    }
}
#pragma mark - Clipboard

- (void)selectAllTextMessageInCell:(id<MXKCellRendering>)cell
{
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    selectedText = roomBubbleTableViewCell.bubbleData.textMessage;
    roomBubbleTableViewCell.allTextHighlighted = YES;
    
    // Display Menu (dispatch is required here, else the attributed text change hides the menu)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIMenuControllerDidHideMenuNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIMenuControllerDidHideMenuNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // Deselect text
            roomBubbleTableViewCell.allTextHighlighted = NO;
            selectedText = nil;
            
            [UIMenuController sharedMenuController].menuItems = nil;
            
            [[NSNotificationCenter defaultCenter] removeObserver:UIMenuControllerDidHideMenuNotificationObserver];
            UIMenuControllerDidHideMenuNotificationObserver = nil;
        }];
        
        [self becomeFirstResponder];
        UIMenuController *menu = [UIMenuController sharedMenuController];
        menu.menuItems = @[[[UIMenuItem alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"share"] action:@selector(share:)]];
        [menu setTargetRect:roomBubbleTableViewCell.messageTextView.frame inView:roomBubbleTableViewCell];
        [menu setMenuVisible:YES animated:YES];
    });
}

- (void)copy:(id)sender
{
    [[UIPasteboard generalPasteboard] setString:selectedText];
}

- (void)share:(id)sender
{
    if (selectedText)
    {
        NSArray *activityItems = [NSArray arrayWithObjects:selectedText, nil];
        
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        
        if (activityViewController)
        {
            [self presentViewController:activityViewController animated:YES completion:nil];
        }
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (selectedText.length && (action == @selector(copy:) || action == @selector(share:)))
    {
        return YES;
    }
    return NO;
}

- (BOOL)canBecomeFirstResponder
{
    return (selectedText.length != 0);
}

#pragma mark - Download attachment

- (void)downloadAttachmentInCell:(id<MXKCellRendering>)cell success:(void (^)(NSString *cacheFilePath))success failure:(void (^)(NSError *error))failure
{
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    
    // Check whether the attachment is already available
    NSString *cacheFilePath = roomBubbleTableViewCell.bubbleData.attachmentCacheFilePath;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath])
    {
        // Done
        if (success)
        {
            success (cacheFilePath);
        }
    }
    else
    {
        // Trigger download if it is not already in progress
        MXKMediaLoader* loader = [MXKMediaManager existingDownloaderWithOutputFilePath:cacheFilePath];
        NSString *attachmentURL = roomBubbleTableViewCell.bubbleData.attachmentURL;
        if (!loader)
        {
            loader = [MXKMediaManager downloadMediaFromURL:attachmentURL andSaveAtFilePath:cacheFilePath];
        }
        
        if (loader)
        {
            [roomBubbleTableViewCell startProgressUI];
            
            // Add observers
            onAttachmentDownloadEndObs = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKMediaDownloadDidFinishNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                // Sanity check
                if ([notif.object isKindOfClass:[NSString class]])
                {
                    NSString* url = notif.object;
                    NSString* cacheFilePath = notif.userInfo[kMXKMediaLoaderFilePathKey];
                    
                    if ([url isEqualToString:attachmentURL] && cacheFilePath.length)
                    {
                        // Remove the observers
                        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadEndObs];
                        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadFailureObs];
                        onAttachmentDownloadEndObs = nil;
                        onAttachmentDownloadFailureObs = nil;
                        
                        if (success)
                        {
                            success (cacheFilePath);
                        }
                    }
                }
            }];
            
            onAttachmentDownloadFailureObs = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKMediaDownloadDidFailNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                // Sanity check
                if ([notif.object isKindOfClass:[NSString class]])
                {
                    NSString* url = notif.object;
                    NSError* error = notif.userInfo[kMXKMediaLoaderErrorKey];
                    
                    if ([url isEqualToString:attachmentURL])
                    {
                        // Remove the observers
                        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadEndObs];
                        [[NSNotificationCenter defaultCenter] removeObserver:onAttachmentDownloadFailureObs];
                        onAttachmentDownloadEndObs = nil;
                        onAttachmentDownloadFailureObs = nil;
                        
                        if (failure)
                        {
                            failure (error);
                        }
                    }
                }
            }];
        }
        else if (failure)
        {
            failure (nil);
        }
    }
}

#pragma mark - UITableView delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [roomDataSource cellHeightAtIndex:indexPath.row withMaximumWidth:tableView.frame.size.width];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dismiss keyboard when user taps on messages table view content
    [self dismissKeyboard];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)])
    {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // Detect vertical bounce at the top of the tableview to trigger pagination
    if (scrollView == _bubblesTableView)
    {
        // paginate ?
        if (scrollView.contentOffset.y < -64)
        {
            [self triggerBackPagination];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Consider this callback to reset scrolling to bottom flag
    isScrollingToBottom = NO;
}

#pragma mark - MXKRoomTitleViewDelegate

- (void)roomTitleView:(MXKRoomTitleView*)titleView presentMXKAlert:(MXKAlert*)alert
{
    [self dismissKeyboard];
    [alert showInViewController:self];
}

- (void)roomTitleView:(MXKRoomTitleView*)titleView isSaving:(BOOL)saving
{
    if (saving)
    {
        [self startActivityIndicator];
    }
    else
    {
        [self stopActivityIndicator];
    }
}

#pragma mark - MXKRoomInputToolbarViewDelegate

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView isTyping:(BOOL)typing
{
    if (typing)
    {
        // Reset potential placeholder (used in case of wrong command usage)
        inputToolbarView.placeholder = nil;
    }
    [self handleTypingNotification:typing];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView heightDidChanged:(CGFloat)height
{
    _roomInputToolbarContainerHeightConstraint.constant = height;
    
    // Lays out the subviews immediately
    // We will scroll to bottom if the bottom of the table is currently visible
    BOOL shouldScrollToBottom = [self isBubblesTableScrollViewAtTheBottom];
    CGFloat bubblesTableViewBottomConst = _roomInputToolbarContainerBottomConstraint.constant + _roomInputToolbarContainerHeightConstraint.constant;
    if (_bubblesTableViewBottomConstraint.constant != bubblesTableViewBottomConst)
    {
        _bubblesTableViewBottomConstraint.constant = bubblesTableViewBottomConst;
        // Force to render the view
        [self.view layoutIfNeeded];
        if (shouldScrollToBottom)
        {
            [self scrollBubblesTableViewToBottomAnimated:NO];
        }
    }
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendTextMessage:(NSString*)textMessage
{
    // Handle potential IRC commands in typed string
    if ([self isIRCStyleCommand:textMessage] == NO)
    {
        // Send text message in the current room
        [self sendTextMessage:textMessage];
    }
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendImage:(UIImage*)image
{
    // Let the datasource send it and manage the local echo
    [roomDataSource sendImage:image success:nil failure:^(NSError *error)
    {
        // Nothing to do. The image is marked as unsent in the room history by the datasource
        NSLog(@"[MXKRoomViewController] sendImage failed. Error:%@", error);
    }];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendVideo:(NSURL*)videoLocalURL withThumbnail:(UIImage*)videoThumbnail
{
    // Let the datasource send it and manage the local echo
    [roomDataSource sendVideo:videoLocalURL withThumbnail:videoThumbnail success:nil failure:^(NSError *error)
    {
        // Nothing to do. The video is marked as unsent in the room history by the datasource
        NSLog(@"[MXKRoomViewController] sendVideo failed. Error:%@", error);
    }];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView presentMXKAlert:(MXKAlert*)alert
{
    [self dismissKeyboard];
    [alert showInViewController:self];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView presentMediaPicker:(UIImagePickerController*)mediaPicker
{
    [self dismissKeyboard];
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView dismissMediaPicker:(UIImagePickerController*)mediaPicker
{
    if (self.presentedViewController == mediaPicker)
    {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

# pragma mark - Typing notification

- (void)handleTypingNotification:(BOOL)typing
{
    NSUInteger notificationTimeoutMS = -1;
    if (typing)
    {
        // Check whether a typing event has been already reported to server (We wait for the end of the local timout before considering this new event)
        if (typingTimer)
        {
            // Refresh date of the last observed typing
            lastTypingDate = [[NSDate alloc] init];
            return;
        }
        
        // Launch a timer to prevent sending multiple typing notifications
        NSTimeInterval timerTimeout = MXKROOMVIEWCONTROLLER_DEFAULT_TYPING_TIMEOUT_SEC;
        if (lastTypingDate)
        {
            NSTimeInterval lastTypingAge = -[lastTypingDate timeIntervalSinceNow];
            if (lastTypingAge < timerTimeout)
            {
                // Subtract the time interval since last typing from the timer timeout
                timerTimeout -= lastTypingAge;
            }
            else
            {
                timerTimeout = 0;
            }
        }
        else
        {
            // Keep date of this typing event
            lastTypingDate = [[NSDate alloc] init];
        }
        
        if (timerTimeout)
        {
            typingTimer = [NSTimer scheduledTimerWithTimeInterval:timerTimeout target:self selector:@selector(typingTimeout:) userInfo:self repeats:NO];
            // Compute the notification timeout in ms (consider the double of the local typing timeout)
            notificationTimeoutMS = 2000 * MXKROOMVIEWCONTROLLER_DEFAULT_TYPING_TIMEOUT_SEC;
        }
        else
        {
            // This typing event is too old, we will ignore it
            typing = NO;
            NSLog(@"[MXKRoomVC] Ignore typing event (too old)");
        }
    }
    else
    {
        // Cancel any typing timer
        [typingTimer invalidate];
        typingTimer = nil;
        // Reset last typing date
        lastTypingDate = nil;
    }
    
    // Send typing notification to server
    [roomDataSource.room sendTypingNotification:typing
                                        timeout:notificationTimeoutMS
                                        success:^{
                                            // Reset last typing date
                                            lastTypingDate = nil;
                                        } failure:^(NSError *error)
    {
        NSLog(@"[MXKRoomVC] Failed to send typing notification (%d) failed: %@", typing, error);
        // Cancel timer (if any)
        [typingTimer invalidate];
        typingTimer = nil;
    }];
}

- (IBAction)typingTimeout:(id)sender
{
    [typingTimer invalidate];
    typingTimer = nil;
    
    // Check whether a new typing event has been observed
    BOOL typing = (lastTypingDate != nil);
    // Post a new typing notification
    [self handleTypingNotification:typing];
}


# pragma mark - Attachment handling

- (void)showAttachmentInCell:(id<MXKCellRendering>)cell
{
    [self dismissKeyboard];
    
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    MXKImageView *attachment = roomBubbleTableViewCell.attachmentView;
    
    // Retrieve attachment information
    NSDictionary *content = attachment.mediaInfo;
    NSUInteger msgtype = ((NSNumber*)content[@"msgtype"]).unsignedIntValue;
    if (msgtype == MXKRoomBubbleCellDataTypeImage)
    {
        NSString *url = content[@"url"];
        if (url.length)
        {
            NSString *mimetype = nil;
            if (content[@"info"])
            {
                mimetype = content[@"info"][@"mimetype"];
            }
            
            // Use another MXKImageView that will show the fullscreen image URL in fullscreen
            highResImageView = [[MXKImageView alloc] initWithFrame:self.view.frame];
            highResImageView.stretchable = YES;
            highResImageView.mediaFolder = roomDataSource.roomId;
            [highResImageView setImageURL:url withType:mimetype andImageOrientation:UIImageOrientationUp previewImage:attachment.image];
            [highResImageView showFullScreen];
            
            // Add tap recognizer to hide attachment
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideAttachmentView)];
            [tap setNumberOfTouchesRequired:1];
            [tap setNumberOfTapsRequired:1];
            [highResImageView addGestureRecognizer:tap];
            highResImageView.userInteractionEnabled = YES;
        }
    }
    else if (msgtype == MXKRoomBubbleCellDataTypeVideo)
    {
        NSString *url =content[@"url"];
        if (url.length)
        {
            NSString *mimetype = nil;
            if (content[@"info"])
            {
                mimetype = content[@"info"][@"mimetype"];
            }
            
            AVAudioSessionCategory = [[AVAudioSession sharedInstance] category];
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            videoPlayer = [[MPMoviePlayerController alloc] init];
            if (videoPlayer != nil)
            {
                videoPlayer.scalingMode = MPMovieScalingModeAspectFit;
                [self.view addSubview:videoPlayer.view];
                [videoPlayer setFullscreen:YES animated:NO];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(moviePlayerPlaybackDidFinishNotification:)
                                                             name:MPMoviePlayerPlaybackDidFinishNotification
                                                           object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(moviePlayerWillExitFullscreen:)
                                                             name:MPMoviePlayerWillExitFullscreenNotification
                                                           object:videoPlayer];
                selectedVideoURL = url;
                
                // check if the file is a local one
                // could happen because a media upload has failed
                if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoURL])
                {
                    selectedVideoCachePath = selectedVideoURL;
                }
                else
                {
                    selectedVideoCachePath = [MXKMediaManager cachePathForMediaWithURL:selectedVideoURL andType:mimetype inFolder:roomDataSource.roomId];
                }
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoCachePath])
                {
                    videoPlayer.contentURL = [NSURL fileURLWithPath:selectedVideoCachePath];
                    [videoPlayer play];
                }
                else
                {
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFinishNotification object:nil];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMediaDownloadEnd:) name:kMXKMediaDownloadDidFailNotification object:nil];
                    
                    [MXKMediaManager downloadMediaFromURL:selectedVideoURL andSaveAtFilePath:selectedVideoCachePath];
                }
            }
        }
    }
    else if (msgtype == MXKRoomBubbleCellDataTypeAudio)
    {
    }
    else if (msgtype == MXKRoomBubbleCellDataTypeLocation)
    {
    }
    else if (msgtype == MXKRoomBubbleCellDataTypeFile)
    {
        [self downloadAttachmentInCell:cell success:^(NSString *cacheFilePath) {
            
            NSURL *fileUrl;
            
            // The original attachment body (if any) is reported in bubble text message
            NSString *attachmentBody = roomBubbleTableViewCell.bubbleData.textMessage;
            if ([attachmentBody pathExtension].length)
            {
                // Create a symbolic link to the cached file to keep its original name
                documentSymbolicLinkPath = [[MXKMediaManager getCachePath] stringByAppendingPathComponent:attachmentBody];
                
                [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
                if ([[NSFileManager defaultManager] createSymbolicLinkAtPath:documentSymbolicLinkPath withDestinationPath:cacheFilePath error:nil])
                {
                    fileUrl = [NSURL fileURLWithPath:documentSymbolicLinkPath];
                }
            }
            
            if (!fileUrl)
            {
                // Use the cached file by default
                fileUrl = [NSURL fileURLWithPath:cacheFilePath];
            }
            
            documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileUrl];
            
            [documentInteractionController setDelegate:self];
            
            if (![documentInteractionController presentPreviewAnimated:YES])
            {
                if (![documentInteractionController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES])
                {
                    documentInteractionController = nil;
                    if (documentSymbolicLinkPath)
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
                        documentSymbolicLinkPath = nil;
                    }
                }
            }

        } failure:nil];
    }
}

- (void)onMediaDownloadEnd:(NSNotification *)notif
{
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString* url = notif.object;
        if ([url isEqualToString:selectedVideoURL])
        {
            // remove the observers
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKMediaDownloadDidFinishNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKMediaDownloadDidFailNotification object:nil];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoCachePath])
            {
                videoPlayer.contentURL = [NSURL fileURLWithPath:selectedVideoCachePath];
                [videoPlayer play];
            }
            else
            {
                NSLog(@"[RoomVC] Video Download failed"); // TODO we should notify user
                [self hideAttachmentView];
            }
        }
    }
}

- (void)hideAttachmentView
{
    selectedVideoURL = nil;
    selectedVideoCachePath = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerWillExitFullscreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKMediaDownloadDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKMediaDownloadDidFailNotification object:nil];
    
    if (highResImageView)
    {
        for (UIGestureRecognizer *gestureRecognizer in highResImageView.gestureRecognizers)
        {
            [highResImageView removeGestureRecognizer:gestureRecognizer];
        }
        [highResImageView removeFromSuperview];
        highResImageView = nil;
    }
    
    // Restore audio category
    if (AVAudioSessionCategory)
    {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategory error:nil];
    }
    if (videoPlayer)
    {
        [videoPlayer stop];
        [videoPlayer setFullscreen:NO];
        [videoPlayer.view removeFromSuperview];
        videoPlayer = nil;
    }
}

- (void)moviePlayerWillExitFullscreen:(NSNotification*)notification
{
    if (notification.object == videoPlayer)
    {
        [self hideAttachmentView];
    }
}

- (void)moviePlayerPlaybackDidFinishNotification:(NSNotification *)notification
{
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSNumber *resultValue = [notificationUserInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    MPMovieFinishReason reason = [resultValue intValue];
    
    // error cases
    if (reason == MPMovieFinishReasonPlaybackError)
    {
        NSError *mediaPlayerError = [notificationUserInfo objectForKey:@"error"];
        if (mediaPlayerError)
        {
            NSLog(@"[RoomVC] Playback failed with error description: %@", [mediaPlayerError localizedDescription]);
            [self hideAttachmentView];
            
            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:mediaPlayerError];
        }
    }
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller
{
    return self;
}

// Preview presented/dismissed on document.  Use to set up any HI underneath.
- (void)documentInteractionControllerWillBeginPreview:(UIDocumentInteractionController *)controller
{
    documentInteractionController = controller;
}

- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller
{
    documentInteractionController = nil;
    if (documentSymbolicLinkPath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
        documentSymbolicLinkPath = nil;
    }
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    documentInteractionController = nil;
    if (documentSymbolicLinkPath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
        documentSymbolicLinkPath = nil;
    }
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    documentInteractionController = nil;
    if (documentSymbolicLinkPath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:documentSymbolicLinkPath error:nil];
        documentSymbolicLinkPath = nil;
    }
}


@end
