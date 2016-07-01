Changes in MatrixKit in 0.3.10 (2016-07-01)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.9).
 * MXKRoomDataSource: Add the ability to peek into a room.
 * MXKRoomDataSource: Add Markdown typing support.
 * MXKRoomViewController: Use room peeking in room preview.
 * MXKRoomViewController: when opening a permalink, center the corresponding event on the screen.
 * MXKRoomViewController: Add missing slash commands: /invite, /part and /topic (https://github.com/vector-im/vector-ios/issues/223)
 * MXKRoomViewController: Expose [setAttachmentsViewerClass:].
 * MXKRoomViewController: Rename joinRoomWithRoomId to joinRoomWithRoomIdOrAlias.
 * MXKRecentListViewController: Add sanity check to prevent infinite loop.
 * MXKSearchViewController: Improved memory management.
 * MXKContact: add sorting display name definition.
 * MXKContact: Add hasPrefix method.
 * MXKEventFormatter: Support of display of "org.matrix.custom.html" formatted message body (#124).
 * MXKTableViewCellWithLabelAndSwitch: Update UISwitch constraints.

Bug fixes:
 * Room screen:  Tap on attached video does nothing (https://github.com/vector-im/vector-ios/issues/380)
 * Hitting back after search results does not refresh results (https://github.com/vector-im/vector-ios/issues/190)
 * App crashes on : [<__NSDictionaryM> valueForUndefinedKey:] this class is not key value coding-compliant for the key <redacted>.
 * MXKEventFormatter: Add sanity check on event content values to "-[__NSCFDictionary length]: unrecognized selector sent to instance"
 * MXKRoomActivitiesView: Fix exception on undefined MXKRoomActivitiesView.xib.
 * App freezes on iOS8 when user goes back on Recents from a Room Chat.
 * MXKTools: The unit of formatted seconds interval is 'ss' instead of 's'.
 * Room settings: refresh on room state change.
 * App crashes on '/join' command when no param is provided.

Changes in MatrixKit in 0.3.9 (2016-06-02)
===============================================

Bug fix:
 * Invitation preview button is broken.

Changes in MatrixKit in 0.3.8 (2016-06-01)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.8).
 * MXKRoomDataSource: Display all call events (invite, answer, hangup).
 * MXKAuthenticationViewController: Expose [onFailureDuringAuthRequest:].
 * MXKAuthenticationViewController: Support "Forgot Password".
 * MXKRoomMemberListViewController: Expose scrollToTop method.
 * MXKAccount: logout when the access token is no more valid.
 * MXKAccount: Refresh pusher (if any) when the app is resumed.
 * MXKRoomViewController: Do nothing when clicking on an unsent media.
 * MXKTableViewCell: expose layout constraints.
 * MXKTableViewCell: Define display box types.
 * MXKWebViewViewController: Support local HTML file + Handle goBack option.
 * MXKRoomMemberDetailsViewController: Support 'Mention' option.
 * MXKRecentListViewController: Apply apple look&feel on overscroll.
 * MXKRoomDataSourceManager: add missed discussions count.
 * MXKSearchViewController: Handle correctly end of search.

Bug fixes:
 * Application can crash when a video failed to be converted before sending.
 * Loading one image thumbnail in a sequence seems to set all fullres images downloading.
 * It's too hard to press names to auto-insert nicks.
 * It sound like something is filling up the logs.
 * App crashes on room members.

Changes in MatrixKit in 0.3.7 (2016-05-04)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.7).
 * MXKRecentTableViewCell: Support user's action on recent cell.
 * MXKTools: Add formatSecondsIntervalFloored (Format time interval but rounded to the nearest time unit below).
 * MXKTools: i18n'ed formatSecondsInterval methods.
 * MXKRoomBubbleTableViewCell: Support tap on sender name label
 * MXKRoomViewController: Insert sender name in text input by tapping on avatar or display name.
 * Ability to report abuse
 * Ability to ignore users

Bug fixes:
 * Handle the error on joining a room where everyone has left.
 * Video playback stops when you rotate the device.
 * Enable notifications on your device' toggle spills over the side on an iPhone 5 display.

Changes in MatrixKit in 0.3.6 (2016-04-26)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.6).
 * MXKRoomViewController: Support room preview.
 * MXKRoomViewController: Added "joinRoomWithRoomId:andSignUrl:" to join a room from a 3PID invitation.
 * MXKRoomViewController: input tool bar and activities view may be removed on demand.
 * MXKCellRenderingDelegate: Added shouldDoAction delegate operation (a mechanism to ask the app if a link can be opened automatically by the system).
 * Media Picker - Video playback: In case of error, display the navigation bar so that the user can leave this screen.
 * MXKAuthenticationViewController - Registration: support next_link from email validation.

Bug fixes:
 * The hint text animated weirdly horizontally after i send msgs.
 * MXKRoomDataSource: Fix infinite loop on initial pagination.
 * MXKAuthenticationViewController: The filled userId and password must be associated to the authentication session before launching email validation with next_link field.
 * MXKAuthenticationViewController: Fix registration cancellation.
 * Chat screen: lag during the history scrolling.
 * Chat screen: jump on an incoming messages when the user scrolls (even with no back pagination).
 * Chat screen: wrong attachment is opened.
 * Wrong application icon badge number.

Changes in MatrixKit in 0.3.5 (2016-04-08)
===============================================

Improvements:
 * MXKAccountManager: API change - [openSessionForActiveAccounts] is replaced by [prepareSessionForActiveAccounts]. This new method checks for each enabled account if a matrix session is already opened. It opens a matrix session for each enabled account which doesn't have a session.
 * MXK3PID: support new email binding mechanism.
 * MXKAuthenticationViewController, MXKAuthInputsView: Support registration based on MXAuthenticationSession class.
 * MXKAuthenticationRecaptchaWebView: Display a reCAPTCHA widget into a webview.
 * MXKAccountDetailsViewController: Handle the linked emails.
 * MXKAccount: Store (permanently) 3PIDs.
 * MXKRecentsDataSource: Remove room notifications and room tags handling (These operations are handled by inherited classes).
 * MXKContactManager: List email addresses from the local address book (see 'localEmailContacts').
 * MXKAccountManager: Added accountKnowingRoomWithRoomIdOrAlias method.

Bug fixes:
 * Search: 'no result' label is persistent #75.
 * MXKAccount: the push gateway URL must be configurable #76.
 * Multiple invitations on Start Chat action.

Changes in MatrixKit in 0.3.4 (2016-03-17)
===============================================

Improvements:
 * MXKWebViewViewController: add view controller for webview display.

Bug fixes:
 * Chat Screen: scrolling to bottom when opening new rooms seems unreliable.
 * Chat Screen: Wrong displayName and wrong avatar are displayed on invitation.
 * Chat Screen: Some messages are displayed twice.
 * Chat Screen: Some unsent messages are persistent.
 * Fix missing loading wheel when app is resumed.

Changes in MatrixKit in 0.3.3 (2016-03-07)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.3).
 * MXKRoomDataSourceManager: Handle the current number of unread messages that match the push notification rules.
 * MXKRoomDataSource: Remove the timestamp of unsent messages on data reload.
 * MXKRoomViewController: Support the display of a timeline from the past.
 * MXKRoomBubbleCellData: Improve the computation of the text components position.
 * MXKViewControllerHandling: Define the default tint of the navigation bar.
 * MXKViewControllerHandling: Add flag to disable navigation bar tint color change on network status change.
 * MXKRoomBubbleTableViewCell: Add property to disable the default handling of the long press on event.
 * MXKRoomMemberDetailsViewController has been refactored.
 * MXKRoomInputToolbarView: Tells the delegate that the user is typing when textView did begin editing.
 * MXKRoomInputToolbarView: Add option to enable media auto saving.
 * MXKRoomViewController: Add missing constraint on Activities view.

Bug fixes:
 * MXKEventFormater: Fixed crash ("NSConcreteMutableAttributedString add Attribute:value:range:: nil value") when trying to display bad formatted links.
 * MXKRoomDataSource: At startup, recents are not updated for rooms with a gap during server sync.
 * MXKAttachmentsViewController: Remove play icon on videos while they're playing.
 * MXKRoomDataSource: A sent message may appear as unsent.
 * MXKRoomViewController: Fixed jumps when going forwards. Backwards pagination should be smoother.

Changes in MatrixKit in 0.3.2 (2016-02-09)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.2).
 * MXKRoomViewController: Avoid to make pagination request when opening the page while there may be messages available in the store.
 * MXKViewController/MXKTableViewController: Activity indicator. Do not show it if the stopActivityIndicator is called just after (less than 0.3s)
 * Handle email invitation.

Bug fixes:
 * Messages being sent (echoes) were sometimes displayed in red.
 * Deleted unsent messages keep coming back when the app is relaunched.
 * If messages arrive whilst you are scrolled back, the scroll offset jumps.

Changes in MatrixKit in 0.3.1 (2016-01-29)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.1).
 * MXKAuthenticationViewController: Keep the current inputs view when it is still relevant after auth flow refresh.
 * MXKAuthenticationViewController: Improve scroller content size handling.

Changes in MatrixKit in 0.3.0 (2016-01-22)
===============================================

Improvements:
 * MXKDataSource: The table/collection view cell classes are now defined by the data source delegate (see README).
 * MXKRecentsDataSource: Add methods to get, leave or tag a room.
 * MXKRecentsDataSource: Add method to mute/unmute room notifications.
 * MXKRecentsDataSource: Add kMXSessionInvitedRoomsDidChangeNotification observer.
 * MXKSearchViewController: Add reusable view controller for messages search (add dedicated resources: MXKSearchDataSource, MXKSearchCellData, MXKSearchTableViewCell).
 * MXKEventFormatter: Add timeStringFromDate method to generate the time string of a date by considered the current system time formatting.
 * MXKRoomBubbleCellData: Add nullable ’senderAvatarPlaceholder’ property. It is used when url is nil, or during avatar download.
 * MXKAccount: Add the ‘replacePassword’ method.
 * MXKAccount: Enable Background Sync (Active when push body will contain ‘content-available’ key).
 * MXKRoomDataSource: Add a new flag 'useCustomReceipts' to disable the default display of read receipts by MatrixKit.
 * MXKRoomBubbleTableViewCell: Rename inherited classes (MXKRoomIncomingAttachmentWithoutSenderInfoBubbleCell…).
 * MXKRoomBubbleTableViewCell: Add overlay container.
 * MXKRoomBubbleTableView: Add member display name in text input when user taps on avatar.
 * MXKRoomBubbleTableViewCell: Add listener to content view tap.
 * MXKRoomBubbleTableViewCell: Add listener to long press on the avatar view.
 * MXKRoomBubbleTableViewCell: Improve cell height computation by introducing some constraints.
 * Replace MXKReceiptAvartarsContainer with MXKReceiptSendersContainer.
 * MXKReceiptSendersContainer: Handle read receipts for incoming messages too.
 * MXKAccount: Use “<Bundle DisplayName> (iOS)” as app display name for notification pusher.
 * MXKEventFormatter: Define properties to allow formatted string customization (color and font).
 * MXKContactManager: Define the modes of the contact creation from the room members.
 * MXKRoomSettingsViewController: Reusable view controller dedicated to room settings.
 * MXKRoomInputToolbarViewWithHPGrowingText: Define growingTextView as protected field.
 * NSBundle+MatrixKit: Customize the table used to retrieve the localized version of a string. If the key is not defined in this table, the localized string is retrieved from the default table "MatrixKit.strings".
 * MXKRoomViewController: Define as protected UIDocumentInteractionController items.
 * MXKRoomViewController: Implement infinite back pagination.
 * MXKRoomViewController: Move as protected the saved placeholder of text input.
 * MXKAttachmentViewController: Hide status bar.
 * MXKImageView: Make public the imageView used as subview (in readonly mode).
 * MXKMediaManager: Return asset URL in case of saving in user's library
 * MXKRoomCreationInputs: Replace image url with image.
 * Add MXKCollectionViewCell class to define custom UICollectionViewCell.
 * Add MXKTableViewCellWithLabelAndMXKImageView class.
 * MXKTools: Rename resizeImage to reduceImage.
 * MXKImageView: Remove ‘mediaInfo’ property.
 * MXKTools: Add method to convert an image to a pattern color.

Bug fixes:
 * SYIOS-183: Store in-progress messages. Pending and unsent messages are now stored.
 * SYIOS-180: Bad scrolling performance on iOS 9.
 * The pusher is deleted and recreated every time the app starts, which is a Bad Idea.
 * iOS breaks catastrophically if you try to attach a photo when landscape. 
 * SYIOS-196 - Performance issue in MXKContactManager when resuming the app.
 * App freezes during back pagination in #matrix-spam.
 * Bing messages are not highlighted in Recents on new login.

Changes in MatrixKit in 0.2.8 (2015-11-30)
===============================================

Improvements:
 * MXKRoomViewController: Add MXKRoomActivitiesView class to display typing information above the input tool bar.
 * MXKViewControllerHandling: remove automatically closed sessions.
 * MXKQueuedEvent: Removed the deep copy of the passed MXEvent.
 * MXKAccount: Use pusher app ids defined in defaults.plist.
 * MXKRoomBubble: Handle sender's name at MXKRoomBubbleTableViewCell level.

Bug fixes:
 * MXKAttachmentsViewController: Back failed on attachment view (iOS8).

Changes in MatrixKit in 0.2.7 (2015-11-13)
===============================================

Improvements:
 * MXKRoomBubbleTableViewCell: Improve resources handling.
 * MXKRoomMemberDetails: Display rounded picture.

Bug fixes:
 * App crashes on an invite event during events stream resume.
 * MXKRoomMemberTableViewCell: App crashes on room members list update.

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
 

