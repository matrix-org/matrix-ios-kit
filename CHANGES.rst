Changes in MatrixKit in 0.2.6 (2015-11-12)
===============================================

Improvements:
 * MXKRoomDataSource: Reduce computation time on read receipts handling.
 * MXKRoomDataSource: Use only one dispatch queue to limit thread switchings.

Bug fixes:
 * MXKRoomDataSource: Fix performance regression (UI was refreshed even in case of no change).
 * MXKRoomDataSource: Fix "Missing messages in back pagination".

Changes in MatrixKit in 0.2.5 (2015-11-06)
===============================================

Improvements:
 * MXKAuthInputsView: Disable auto correction in login text fields.
 * MXKAccount: Support unrecognized certificate during authentication challenge from a server.
 * MXKRoomViewController: Display read receipts.
 * MXKRoomViewController: Remove blank page while opening a room view controller.
 * MXKRoomViewController: Improve scrolling by reducing lags effect.
 * MXKRoomViewController: Add a spinner in the table header in case of back pagination.
 * MXKRoomViewController: Improve chat history display: When a refresh is triggered whereas the user reads through the history, we anchor the event displayed at the bottom of the history. This is useful in case of screen rotation, event redactions and back pagination triggered by a third part.
 * MXKRoomDataSource: Disable merging mechanism on successive messages from the same sender. Only one event is displayed by bubble. This change was done to reduce scrolling lags.
 * MXKRoomDataSource: Room invitations are displayed as unread messages.
 * MXKAttachment: Add MXKAttachment class to handle room attachments
 * MXKAttachmentsViewController: Add MXKAttachmentsViewController class to display room attachments in a viewer.
 * MXKAppSettings: Define HTTP and HTTPS schemes.
 * MXKRecentListViewController: Display multiple accounts in a consistent order.
 * MXKAuthenticationViewController: Support login fallback option.
 * Optimization: Thumbnail images are stored in a memory cache (LRU cache) to reduce file system access.
 * MXKRoomDataSourceManager: Memory warnings are now handled by MXKRoomDataSourceManager instances to reload unused data source. Matrix session reload is not triggered anymore (fix blank recents on memory warnings).

Bug fixes:
 * SYIOS-126: Timezone changes are not reflected into the app.
 * SYIOS-143: When you send a panorama, it doesn't tell you the resolutions it's targetting, and the predicted res and sizing are tiny. keyboard.
 * SYIOS-152: Time stamps don't obey the system formatting.
 * SYIOS-163: Add ability to see if an image has been sent or not.
 * SYIOS-170: Public Room: room history is wrong when user joins for the second time.
 * SYIOS-171 Cannot create public room in iOS console.
 * MXKRoomBubbleCellData: App crashes during bubble components update.
 * MXKRoomViewController: White stripe on animated gif.
 * MXKTableViewController: Infinite loop on view controller presentation.
 * MXKViewController: In Recents, keyboard gap remains despite there being no.
 * MXKRoomBubbleTableViewCell: Attached images without width and height appear as tiny in chat history.
 * MXKRoomBubbleTableViewCell: The app failed to show in full screen attached image without width and height.
 * MXKImageView: Infinite loading wheel in case of failure during downloading.
 * MXKRecentCellData: Should fix App freeze on last message refresh.
 * MXKContact: Bug Fix App crashed on a fake contact.

Changes in MatrixKit in 0.2.4 (2015-10-14)
===============================================

Improvements:
 * MXKAuthenticationViewController: Strip whitespace around usernames.

Bug fixes:
 * MXKAuthenticationViewController: App crashes in authentication screen on iOS 9.

Changes in MatrixKit in 0.2.3 (2015-09-14)
===============================================

Improvements:
 * MXKRoomViewController: Support animated gif.
 * MXKRoomInputToolbarView: Add ability to paste items from pasteboard (image, video and doc).
 * MXKContact: Consider matrix ids during search session.
 * MXKContactTableCell: Add custom accessory view.
 * MXKContactTableCell: Add options to customize thumbnail display box.
 * MXKRoomDataSourceManager: Register the MXKRoomDataSource-inherited class which is used to instantiate all room data source objects.
 * MXKRoomDataSource: Add pagination per day for rendered bubble cells.
 * MXKDataSource: Add a new step to finalize the initialisation after a potential customization.
 * MXKRoomBubbleCellData: Rename "isSameSenderAsPreviousBubble" flag with "shouldHideSenderInformation".
 * MXKRoomViewController: Animate toolbar height change.
 * Add predefined UITableViewCell classes: MXKTableViewCellWithSearchBar and MXKTableViewCellWithLabelAndImageView.
 
Bug fixes:
 * MXKRoomCreationView: Only private option is displayed.
 * MXKRecentListViewController: The room title overlaps the last message timestamp.
 * Attachments: pptx and similar files are not actually viewable.
 * Attachments: Recorded videos are not saved in user's photo library.

Changes in MatrixKit in 0.2.2 (2015-08-13)
===============================================

Improvements:
 * MXKRecentsDataSource: handle recents edition at MatrixKit level.
 * Add MXKRoomCreationInputs to list fields used during room creation.
 
Bug fixes:
 * Bug fix: App crashes on resume via a push notification.

Changes in MatrixKit in 0.2.1 (2015-08-10)
===============================================

Improvements:
 * MXKAccountDetailsViewController: Add UI to support global notification settings.
 * MatrixKit Error handling: Post MXKErrorNotification event on error.
 * MXKRoomDataSource: Reduce memory usage.
 * MXKRoomDataSource: In case of redacted events, merge adjacent bubbles if they are related to the same sender.
 * Localization: Add localized strings in MatrixKitAssets bundle.
 
Bug fixes:
 * Bug Fix: MXKRoomViewController - App crashes when user selects copy in text input view.
 * Bug Fix: App crashes when user press "Logout all accounts".

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
 

