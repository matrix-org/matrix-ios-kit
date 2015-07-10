Changes in MatrixKit in 0.2.0 (2015-07-10)
===============================================

Improvements:
 * MXKAuthenticationViewController: add reusable UI for authentication.
 * MXKAccount: add MXKAccount object which contains the credentials of a
   logged matrix user. It is used to handle matrix session and presence for
   this user.
 * MXKAccount: Handle Remote and In-App notifications at account level.
 * MXKAccount: clear session store on account logout.
 * MXKAccountManager: support multi-sessions. Existing account may be disabled
   without logout.
 * MXK3PID: Move MXC3PID class in MatrixKit.
 * MXKAccountDetailsViewController: Edit matrix account profile.
 * MXKAccountTableViewCell: reusable model of table view cell to display
   Matrix account.
 * MXKRecentListViewController: search in recents is optional feature.
 * MXKRecentListViewController: In case of multi-sessions recents may be
   interleaved or not. Each session may be collapsed or not.
 * MXKRecentListViewController: Lock recents refresh during server sync 
   (prevent recents flickering during server sync).
 * MXKAppSettings: Define user's presence colour.
 * MXKEventFormatter: Expose colours used when formatting events into
   attributed strings.
 * MXKRoomViewController: Handle progress text input saving (optional
   feature).
 * MXKRoomViewController: Prompt user to select a compression level before
   sending image.
 * MXKRoomViewController: support attachment saving and sharing.
 * MXKRoomViewController: Highlight selected text in bubble.
 * MXKRoomViewController: Support attached files (download/open/share).
 * MXKRoomViewController: Post unrecognised IRC-style command as a message.
 * MXKRoomDataSource: cache sent media (we don't need to download outgoing
   media).
 * MXKRoomBubbleTableViewCell: Make it more reusable. Removed all #define
   constants that take values from xibs.
 * MatrixKit Sample: Update Sample app.
 * Add reusable models of table view cells (MXKTableViewCellWithButton,
   MXKTableViewCellWithLabelAndSwitch...)
 * MXKCallViewController: Add reusable view controller to handle voice and
   video call.
 * MXKRoomTitleView: Add reusable view to handle room title display and
   edition.
 * MXKRoomTitleViewWithTopic: inherit MXKRoomTitleView to handle room topic.
 * MXKRoomCreationView: Add reusable view to handle room creation.
 * MXKPublicRoomTableViewCell: Add reusable table view cell to display public
   room.
 * MXKViewController and MXKTableViewController: support multi-sessions for
   all inherited class.
 * MXKContactManager: Move contacts handling in MatrixKit.
 * MXKContactListViewController: Add reusable view controller to list
   contacts.
 * MXKRecents: add "Mark all as read" option.
 * MXKAccount: add the account user's tint colour: a unique colour fixed by
   the user id. This tint colour may be used to highlight rooms which belong
   to this account's user.
 * Move Images and Sounds into MatrixKitAssets bundle.
 * Add MXKContactDetailsViewController and MXKRoomMemberDetailsViewController.
 
Bug fixes:
 * Bug Fix in registration: the home server base URL was wrong after the
   creation of a new account, which made all requests fail.
 * MXKImageView: Fix button display issue in fullscreen in app without tab
   bar.
 * MXKRoomViewController: Display loading wheel on initial back pagination.
 * MXKRoomViewController: Fix UI refresh when user leaves the current selected
   room.
 * MXKRoomDataSource Manager: add method to release unused manager.
 * Bug Fix: App crash: missing error domain in case of MXKAuthentication
   failure
 * Memory leaks: Dispose properly view controller resources.
 * Performance issue in MXKRoomMembersListViewController: Update correctly
   member's activity information.
 * MXKAppSettings: Add missing synchronise.
 * MXKRoomViewController: Fix scrolling issue when keyboard is opened.
 * MXKRoomViewController: Prevent scroll bounce on keyboard dismiss.
 * MXKRoomViewController: dismiss keyboard when a MXKAlert is presented.
 * Bug Fix: MXKRoomBubbleCellData - "Unsent" button is displayed at the wrong
   place, and it is not active.
 * Bug Fix: Restore download/upload cancellation.
 * Performance issue: Fix issue related to table view cell dequeuing.
 * Bug Fix: MXKImageView - The high resolution image is not displayed on full
   screen at the end of download.
 * Bug Fix: Toggle default keyboard from 123 mode to ABC mode when send button
   is pressed.
 * Bug Fix iOS7: MXKRoomViewController - bubble width is wrong for messages
   ended with 'w' or 'm' character.
 * Bug Fix: When the app is backgrounded during a server sync, the pause is
   postponed at the end of sync.
 * Bug Fix: the client spam the server with setPresence requests.
 * Bug Fix: Blank room - Handle correctly failure during back pagination
   request (see SYN-162 - Bogus pagination token when the beginning of the
   room history is reached).


Changes in MatrixKit in 0.1.0 (2015-04-23)
===============================================

First release.
MatrixKit contains the following reusable UI components:

 * MXKRoomViewController
 * MXKRecentListViewController
 * MXKRoomMemberListViewController
 

