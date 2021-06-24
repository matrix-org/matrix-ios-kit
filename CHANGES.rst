Changes to be released in next version
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Changes in 0.15.2 (2021-06-24)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * MXKAttachment: Added MXKAttachmentTypeVoiceMessage attachment type (vector-im/element-ios/issues/4090).

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.19.2](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.19.2)).

Changes in 0.15.1 (2021-06-21)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXRoomSummary: Adapt removal of `lastMessageEvent` property (vector-im/element-ios/issues/4360).
 * MXKAttachment: Adapt removal of `mimetype` fields (vector-im/element-ios/issues/4303).

🐛 Bugfix
 * MXKCallViewController: Fix status text of a remotely held call.
 * MXKCallViewController: Fix avatar image for outgoing on hold calls.
 * MXKRoomViewController: Fix virtual timeline issues.
 * MXKEventFormatter: Style blockquotes as blocks, fixing fallback display (#836).
 * MXKEventFormatter: Fix display of emote replies (vector-im/element-ios/issues/4081).

⚠️ API Changes
 * Exposed methods for sending audio files and voice messages (vector-im/element-ios/issues/4090).

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.19.1](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.19.1)).

Changes in 0.15.0 (2021-06-02)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKRoomDataSource: Decrypt unsent messages to follow MatrixSDK changes.
 * MXKEncryptionKeysExportView: Define a minimum size for the passphrase.
 * Pod: Update Down to 0.11.0.
 * Logging: Adopted MXLog throughout (vector-im/element-ios/issues/4351)

🐛 Bugfix
 * MXKAccount: Do not propagate errors for timed out initial sync requests (vector-im/element-ios/issues/4054).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.19.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.19.0)).

Changes in 0.14.12 (2021-05-12)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.12](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.12)).

Changes in 0.14.11 (2021-05-07)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKEventFormatter: Expose defaultRoomSummaryUpdater ivar as protected.
 * MXKCallViewController: Add transfer button and implement actions.
 * MXKAuthenticationVC: Expose current HTTP Operation (vector-im/element-ios/issues/4276)
 * MXKAccount: Log reasons for incompatible sync filter (vector-im/element-ios/issues/3921).
 * MXKCallViewController: Handle asserted identity updates.

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * CI: Introduce GH actions.

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.11](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.11)).

Changes in 0.14.10 (2021-04-22)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.10](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.10)).

Changes in 0.14.9 (2021-04-16)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.9](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.9)).

Changes in 0.14.8 (2021-04-14)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * RR are not sent if a typing notification is shown in the timeline (vector-im/element-ios/issues/4209).
 * Outgoing messages edited on another session are not updated in my room history (vector-im/element-ios/issues/4201).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.8](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.8)).

Changes in 0.14.7 (2021-04-09)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * Vertical padding is borked on new attachment UI after going into file selector and out again (vector-im/element-ios/issues/4156).
 * Vertical layout of typing notifs can go wonky (vector-im/element-ios/issues/4159).

⚠️ API Changes
 * MXKRoomBubbleCellDataStoring: Introduce target user ID, display name and avatar URL for room membership events (vector-im/element-ios/issues/4102).

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.7](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.7)).

Changes in 0.14.6 (2021-03-24)
=================================================

✨ Features
 * 

🙌 Improvements
 * Pods: Update JSQMessagesViewController, DTCoreText, Down (vector-im/element-ios/issues/4120).
 * MXKRoomDataSource: Introduce secondaryRoomId and secondaryRoomEventTypes.

🐛 Bugfix
 * Fix collapsing of separately processed events

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.6](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.6)).

Changes in 0.14.5 (2021-03-11)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * MXKRoomDataSource: Fix memory leak in `bubbles` array.

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * Ensure room on event editions.

Improvements:
 * Upgrade MatrixSDK version ([v0.18.5](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.5)).

Changes in 0.14.4 (2021-03-03)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.4](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.4)).

Changes in 0.14.3 (2021-02-26)
=================================================

✨ Features
 * 

🙌 Improvements
 * Crypto: Pre share session keys when typing by default (vector-im/element-ios/issues/4075).

🐛 Bugfix
 * App state: Infinite loading spinner when resuming the app (vector-im/element-ios/issues/4073).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.3](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.3)).

Changes in 0.14.2 (2021-02-24)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKRoomDataSource: Notify subclasses on room change.
 
🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.2](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.2)).

Changes in 0.14.1 (2021-02-12)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.1](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.1)).

Changes in 0.14.0 (2021-02-11)
=================================================

✨ Features
 * 

🙌 Improvements
 * Crypto: Add a MXKAppSettings option to pre-share session keys (vector-im/element-ios/issues/3934).
 * VoIP: DTMF support in calls (vector-im/element-ios/issues/3929).

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.18.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.18.0)).

Changes in 0.13.9 (2021-02-03)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * Login screen: Unexpected request to access the contact book (vector-im/element-ios/issues/3984).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.11](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.11)).

Changes in 0.13.8 (2021-01-27)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.10](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.10)).

Changes in 0.13.7 (2021-01-18)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.9](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.9)).

Changes in 0.13.6 (2021-01-15)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.8](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.8)).

Changes in 0.13.5 (2021-01-14)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKAuthenticationViewController: Expose loginWithParameters method.

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.7](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.7)).

Changes in 0.13.4 (2020-12-18)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * MXKRoomViewController: Fix a crash by not calling UITableViewDataSource method, but dequeuing the cell.

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.6](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.6)).

Changes in 0.13.3 (2020-12-16)
=================================================

✨ Features
 * Data encryption for MXKContactManager and MXKAccountManager using MXKeyProvider (#3866)

🙌 Improvements
 * 

🐛 Bugfix
 * MXKAccountManager: fix a bug that prevents user to stay logged in if V2 file is not initially encrypted (vector-im/element-ios/issues/3866).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.5](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.5)).

Changes in 0.13.2 (2020-12-02)
=================================================

✨ Features
 * Added AES encryption support in MXKContactManager (vector-im/element-ios/issues/3833).
 * Added allowActionsInDocumentPreview property in MXKRoomViewController to show or hide the actions button in document preview. (#3864)

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.4](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.4)).

Changes in 0.13.1 (2020-11-24)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.3](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.3)).

Changes in 0.13.0 (2020-11-17)
=================================================

✨ Features
 * Expose Webview object to SDK consumer (https://github.com/vector-im/element-ios/issues/3829)

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.17.2](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.17.2)).

Changes in 0.12.26 (2020-10-27)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.20](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.20)).

Changes in 0.12.25 (2020-10-14)
=================================================

✨ Features
 * 

🙌 Improvements
 * Make copying & pasting media configurable. 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.19](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.19)).

Changes in 0.12.24 (2020-10-13)
=================================================

✨ Features
 * 

🙌 Improvements
 * 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.18](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.18)).

Changes in 0.12.23 (2020-10-09)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKPasteboardManager: Introduce dedicated pasteboard manager to change the pasteboard used on copy operations (vector-im/element-ios/issues/3732). 

🐛 Bugfix
 * Room: Refresh UI when the app is fully active (vector-im/element-ios/issues/3672).

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.17](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.17)).

Changes in 0.12.22 (2020-10-02)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKAuthenticationViewController: Do not present fallback when there is one unsupported login flow among supported ones (/vector-im/element-ios/issues/3711).

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:


Changes in 0.12.21 (2020-09-30)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.16](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.16)).
 * MXKAppSettings: Introduce `hideUndecryptableEvents`. Disabled by default.
 * Room: Differentiate wordings for DMs.

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.20 (2020-09-16)
=================================================

Features:
 * 

Improvements:
 * 

Bugfix:
 * 

API Change:
 * Disable PushKit pushers by default, see `-[MXKAppSettings allowPushKitPushers]`.

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.19 (2020-09-15)
=================================================

✨ Features
 * 

🙌 Improvements
 * MXKAppSettings: Change some events to be visible (vector-im/element-ios/issues/3629). 

🐛 Bugfix
 * 

⚠️ API Changes
 * 

🗣 Translations
 * 
    
🧱 Build
 * 

Others
 * 

Improvements:


Changes in 0.12.18 (2020-09-08)
=================================================

Features:
 * 

Improvements:
 * 

Bugfix:
 * MXKAccount: Fix crash on logout.

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.17 (2020-09-03)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.15](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.15)).
 * 

Bugfix:
 * PushKit: Delete any pending PushKit pusher (vector-im/riot-ios/issues/3577).

API Change:
 * 

Translations:
 * 

Others:
 * MXKEventFormatter: Replace cmark with Down (vector-im/element/issues/3569). 

Build:
 * 

Test:
 * 

Changes in 0.12.16 (2020-08-28)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.14](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.14)).
 * 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.15 (2020-08-25)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.13](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.13)).
 * 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.14 (2020-08-19)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.12](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.12)).
 * 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.13 (2020-08-14)
=================================================

Features:
 * 

Improvements:
 * Introduce allowLocalContactsAccess on MXKContactManager. 
 * Introduce messageDetailsAllowSaving & messageDetailsAllowSharing on MXKAppSettings.

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.12 (2020-08-13)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.11](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.11)).
 * 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.11 (2020-08-07)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.10](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.10)).
 * Enhance auth fallback webview logs. 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.10 (2020-08-05)
=================================================

Features:
 * 

Improvements:
 * Upgrade MatrixSDK version ([v0.16.9](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.9)).
 * 

Bugfix:
 * 

API Change:
 * 

Translations:
 * 

Others:
 * 

Build:
 * 

Test:
 * 

Changes in 0.12.9 (2020-07-28)
==============================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.8](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.8)).

Changes in MatrixKit in 0.12.8 (2020-07-13)
=========================================

Improvements:
 * MXKAttachmentsViewController: MPMoviePlayerController replaced with AVPlayerViewController (PR #651).
 * MXKCallViewController: Fix incoming call view for ringing state (PR #669).
 * MXKAccount: Make sure PushKit pusher removed before losing the push token (vector-im/riot-ios/issues/3369).
 * Strings: Use you instead of display name on notice events (vector-im/riot-ios/issues/3282).

Bug fix:
 * MXKImageView: Consider safe area insets when displayed fullscreen (PR #649).
 * MXKAccount: Add format and fallback_content to APNS push data (vector-im/riot-ios/issues/3325).

Changes in MatrixKit in 0.12.7 (2020-05-xx)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.6](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.6)).
 * DTCoreText: Update DTCoreText dependency to 1.6.23 minimum to be sure to not reference UIWebView.
 * MXKCountryPickerViewController: Replace deprecated UISearchDisplayController by UISearchViewController.
 * MXKLanguagePickerViewController: Replace deprecated UISearchDisplayController by UISearchViewController.
 * MXKAppSettings: Add an option to hide un-decryptable events before joining the room.
 * MXKRoomDataSource: Hide un-decryptable messages that were sent while the user was not in the room if needed.

Bug fix:
 * MXKRoomDataSource: Wait for store data ready when finalizing initialization on data source (vector-im/riot-ios/issues/3159).
 * MXKLanguagePickerViewController: Fix selected cell reuse issue.
 * MXKRoomDataSource: Wait for initial event existence if provided (vector-im/riot-ios/issues/3290).
 * MXKRoomDataSource: Convert one-time observers to block variables to avoid releasing (vector-im/riot-ios/issues/3337).

Changes in MatrixKit in 0.12.6 (2020-05-18)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.5](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.5)).

Changes in MatrixKit in 0.12.5 (2020-05-13)
=========================================

Bug fix:
 * Remove UIWebView dependency from MXKAuthenticationViewController (PR #666).

Changes in MatrixKit in 0.12.4 (2020-05-11)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.4](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.4)).

Bug fix:
 * Replace UIWebView with WKWebView (PR #663).
 * Fix range of allowed surrogate emoji characters to 0x1d000-0x1f9ff.

Changes in MatrixKit in 0.12.3 (2020-05-07)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.3](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.3)).

Changes in MatrixKit in 0.12.2 (2020-05-01)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.2](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.2)).

Changes in MatrixKit in 0.12.1 (2020-04-24)
=========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.1](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.1)).

Bug fix:
 * MXKAttachmentsViewController: Make navigation bar respect to safe area insets (PR #659).
 * MXKAuthenticationViewController: Remove bottomLayoutGuide and content view equal width constraints (PR #660).

Changes in MatrixKit in 0.12.0 (2020-04-17)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.16.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.16.0)).
 * MXKRoomBubbleTableViewCell: Handle content view tap and long press when there is no `messageTextView` or `attachmentView` properties.
 * MXKRoomBubbleComponent: Add a property to indicate if an encryption badge should be shown.
 * MXKRoomBubbleCellData: Add a property to indicate if a bubble component needs to show encryption badge.
 * MXKEventFormatter: E2E, hide duplicate message warnings (vector-im/riot-ios#2910).
 * MXKEventFormatter: E2E, hide the algo used when turning on encryption (vector-im/riot-ios#2939).
 * Push notifications: Implement logic to use also a secondary appId for VoIP pusher on debug builds, like for APNS pusher.
 * SwiftUTI: Remove the no more maintained pod. Embed code instead.

API break:
 * MXKRoomBubbleComponent: Add session parameter to init and update method.

Bug fix:
 * MXKImageView: Consider safe area insets when displayed fullscreen (PR #649).

Changes in MatrixKit in 0.11.4 (2020-04-01)
==========================================

 Bug fix:
 * Push notifications: Avoid any automatic deactivation (vector-im/riot-ios#3017).

Changes in MatrixKit in 0.11.3 (2019-12-05)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.15.2](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.15.2)).
 * MXKRoomBubbleTableViewCell: Improve link gesture recognition.

Changes in MatrixKit in 0.11.2 (2019-11-06)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.15.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.15.0)).
 * MXKEventFormatter: In the case of "in reply to" event, replace the user Matrix ID by his display name when available (vector-im/riot-ios/issues/2154).
 * Groups: Load them only after the session got sync'ed with the homeserver (vector-im/riot-ios/issues/2793).
 * MXKRoomViewController: Add possibility to prevent `bubblesTableView` scroll using `contentOffset`.
 * MXKAccount: Handle updated MXBackgroundModeHandler and now use MXBackgroundTask.

Bug fix:
 * MXKRoomBubbleCellData: Fix a crash in `shouldHideSenderName` method.
 * Pasteboard: Fix a crash when passing a nil object to `UIPasteboard`.
 * MXKImageView: UI API called from background thread (#517).

Changes in MatrixKit in 0.11.1 (2019-10-11)
==========================================

Bug fix:
 * MXKContactManager: Fix assertion failure because of early call of updateMatrixIDsForAllLocalContacts.

Changes in MatrixKit in 0.11.0 (2019-10-11)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.14.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.14.0)).
 * MXKDeviceView: Make clear that device names are publicly readable (vector-im/riot-ios/issues/2662).
 * Privacy: Remove the bind true flag from 3PID adds in settings (vector-im/riot-ios/issues/2650).
 * Privacy: Remove the ability to set an IS at login/registration (vector-im/riot-ios/issues/2661).
 * Privacy: Use wellknown to discover the IS of a custom HS (vector-im/riot-ios/issues/2686).
 * Tools: Add human readable MSISDN formatting method.
 * MXKContactManager: Limit the number of full lookups. Do it once per new matrix session.

Bug fix:
 * Display correctly the revoked third-party invite.
 * MXKRoomBubbleTableViewCell: Fix issue with links too easily touchable on iOS 13 (vector-im/riot-ios/issues/2738).
 
Changes in MatrixKit in 0.10.2 (2019-08-08)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.13.1](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.13.1)).
 * Support soft logout (vector-im/riot-ios/issues/2540).
 * MXKRoomBubbleCellData: Add method to get bubble component index from event id.
 * MXKEmail: force in lowercase the email address.
 * Use MXIdentityService to perform identity server requests (vector-im/riot-ios#2647).
 * Support identity server v2 API (vector-im/riot-ios#2603 and /vector-im/riot-ios#2652).

 Bug fix:
 * APNS Push: fix logic when enabling APNS push. Avoid calling nil callback method.

Changes in MatrixKit in 0.10.1 (2019-07-16)
==========================================

Bug fix:
 * Use a usable pod of SwiftUTI.

Changes in MatrixKit in 0.10.0 (2019-07-16)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.13.0](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.13.0)).
 * Update deployment target to iOS 9 (PR #546).
 * Join Room: Support via parameters to better handle federation (vector-im/riot-ios/issues/2547).
 * MXKRoomBubbleTableViewCell: Enhance long press behavior (PR #546).
 * MXKRoomInputToolbarView: Add a property to enable or disable text edition (PR #547).
 * MXKWebViewViewController: Handle authentication challenge in order to support a potential certificates pinning.
 * MXKRoomBubbleCellData: expose reactions made on messages.
 * MXKContactManager: Add a property to override the Matrix users discovering mechanism.
 * MXRoomViewController: Refresh room bubbles cell data messages calculation on orientation change (PR #559).
 * MXKRoomDataSource: Add react and unreact on event methods (PR #560).
 * MXKRoomDataSource: Add can react and can edit an event method (PR #561).
 * MXKRoomDataSource: Support message editing.
 * Add MXKUTI class that represents a Universal Type Identifier.
 * Add MXKDocumentPickerPresenter that presents a controller that provides access to documents or destinations outside the app’s sandbox.
 * Add MXKVideoThumbnailGenerator a utility class to generate a thumbnail image from a video file.

Bug fix:
 * MXKRoomViewController: Handle safe area when asking cell dimension in landscape.
 * Read receipts: They are now counted by MatrixKit.
 * Read receipts: Attach read receipts on non displayed events to their nearest displayed events.
 * MXKRoomBubbleTableViewCell: Add possibility to reset attachement view bottom constraint constant to default value.
 * Push notifications are spontaneously disabling themselves (vector-im/riot-ios/issues/2348).
 
 API break:
  * MXKRoomViewController: Add viaServers parameter to joinRoomWithRoomIdOrAlias.
  * MXKAccount: Remove setEnablePushKitNotifications and replace it by the async enablePushKitNotifications method.
  * MXKAccount: Rename enablePushKitNotifications to hasPusherForPushKitNotifications.
  * MXKAccount: Remove deletePushKitPusher. Use enablePushKitNotifications:NO instead.

Changes in MatrixKit in 0.9.9 (2019-05-03)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.12.5](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.12.5)).
 * Upgraded to Xcode 10.2, fixed most of the compiler warnings, thanks to @tladesignz (PR #536).
 * MXKReceiptSendersContainer: Add possibility to customize `more label` text color (PR #539).
 * MXKEncryptionInfoView: Make it easier to customise.
 * MXKRoomViewController: remove the implicit retains of "self".

Bug fix:
 * Fix some potential crashes with ivar using a weak self (PR #537).
 * MXKSessionRecentsDataSource: Hide a room if needed on room summary change (vector-im/riot-ios/issues/2148).
 * MXKAttachmentsViewController: Fix some retain cycles (PR #544).

Changes in MatrixKit in 0.9.8 (2019-03-21)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.12.4](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.12.4)).

Bug fix:
 * MXKRoomBubbleTableViewCell: Fix tap on file attachment when using a messageTextView of class `MXKMessageTextView` (PR #532).
 * MXKContactManager: some matrix contacts are missing in the search result (offline mode).

Changes in MatrixKit in 0.9.7 (2019-03-13)
==========================================

Bug fix:
 * A left room is stuck in my joined room (vector-im/riot-ios/issues/2318).

Changes in MatrixKit in 0.9.6 (2019-03-08)
==========================================

Improvements:
 * Upgrade MatrixSDK version ([v0.12.3](https://github.com/matrix-org/matrix-ios-sdk/releases/tag/v0.12.3)).
 * Use new MXLoginResponse class.
 * Add `MXKMessageTextView` an UITextView with link detection without text selection.

Bug fix:
 * Handle device_id returned from the fallback login page (vector-im/riot-ios/issues/2301).
 * Room details: the attachments list is empty (or almost) for the encrypted rooms.
 * Quickly tapping on a URL in a message highlights the message rather than opening the URL (vector-im/riot-ios/issues/728).

Changes in MatrixKit in 0.9.5 (2019-02-15)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.12.2).
 * MXKTableViewCellWithButton: Remove all controls events on the button in [self prepareForReuse].

Changes in MatrixKit in 0.9.4 (2019-01-05)
==========================================

Improvements:
 * Chat screen: `Redact` has been renamed to `Remove` to match riot/web (vector-im/riot-ios/issues/2134).

Changes in MatrixKit in 0.9.3 (2019-01-08)
==========================================

Bug fix:
 * Chat screen: wrong thumbnail observed during scrollback (vector-im/riot-ios/issues/1122).

Changes in MatrixKit in 0.9.2 (2019-01-04)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.12.1).
 * Create UIViewController+MatrixKit category.
 * MXKAccount: clear the scan manager database when the session is closed by clearing the cache.
 * MXKTools: Improve image resizing. Add a memory efficient method to reduce image dimensions.
 
Bug fix:
 * Crash in [MXKTools removeMarkedBlockquotesArtifacts:] (vector-im/riot-ios/issues/2147).

Changes in MatrixKit in 0.9.1 (2018-12-12)
==========================================
 
Bug fix:
 * MXKAuthenticationRecaptchaWebView: Use WKWebView so that it can work on iOS 10 (vector-im/riot-ios/issues/2119).
 * Handle correctly media loader cancellation.

Changes in MatrixKit in 0.9.0 (2018-12-06)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.12.0).
 * MXKAccount: Add "antivirusServerURL" property. Set a non-null url to configure the antivirus scanner use.
 * MXKWebViewController: Make it open links with `target="_blank"` within the webview.
 * MXKWebViewController: Improve back navigation by resetting initial right buttons.
 * Replace the deprecated MXMediaManager and MXMediaLoader interfaces use (see matrix-ios-sdk/pull/593).
 
Bug fix:
 * Unexpected empty local contacts list.
 
Deprecated API:
 * MXKAttachment: the properties "actualURL" and "thumbnailURL" are deprecated because only Matrix Content URI should be considered now.
 * MXKAttachment: the property "cacheThumbnailPath" is deprecated, use "thumbnailCachePath" instead.
 * MXKAttachment: [initWithEvent:andMatrixSession:] is deprecated, use [initWithEvent:andMediaManager:] instead.
 * MXKImageView: [setImageURL:withType:andImageOrientation:previewImage:] is deprecated, use [setImageURI:withType:andImageOrientation:previewImage:mediaManager] or [setImageURI:withType:andImageOrientation:toFitViewSize:withMethod:previewImage:mediaManager] instead.
 * MXKReceiptSendersContainer: the property "restClient" is deprecated.
 * MXKReceiptSendersContainer: [initWithFrame:andRestClient:] is deprecated, use [initWithFrame:andMediaManager:] instead.
 * Add media antivirus scan support.

Changes in MatrixKit in 0.8.6 (2018-10-31)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.6).

Bug fix:
 * MXKCallViewController: Fix crash in callRoomStateDidChange (vector-im/riot-ios#2079).
 * MXKEventFormatter: Be robust on malformatted m.relates_to data content (vector-im/riot-ios/issues/2080).

Changes in MatrixKit in 0.8.5 (2018-10-05)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.5).
 * Sync Filter: Refine limit value. Use 15 messages for iPhone 6 & similar screen size.

Bug fix:
 * MXKRoomDataSource: roomState was not updated (vector-im/riot-ios/issues/2058).

Changes in MatrixKit in 0.8.4 (2018-09-26)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.4).
 * Lazy loading: Enable it by default (if the homeserver supports it).
 * Sync Filter: Get enough messages from /sync requests to display a full page without additional homeserver request.
 * MXKRoomViewController: Improve the display of the reason when the user is kicked.
 * MXKEventFormatter: Internationalise the room name computation for rooms with no name.

Bug fix:
 * No automatic scroll down when posting a new message (vector-im/riot-ios/issues/2040).
 * Fix crash in [MXKCallViewController callRoomStateDidChange:] (vector-im/riot-ios/issues/2031).
 * Fix crash in [MXKContactManager refreshLocalContacts] (vector-im/riot-ios/issues/2032).
 * Fix crash when opening a room with unsent message (vector-im/riot-ios/issues/2041).

Changes in MatrixKit in 0.8.3 (2018-08-27)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.3).

Changes in MatrixKit in 0.8.2 (2018-08-24)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.2).
 * MXKAuthenticationVC: Show a "Resource Limit Exceeded" popup if it happens server side (vector-im/riot-ios/issues/1937).
 * Remove keyboard type reset in MXKRoomInputToolbar... classes (vector-im/riot-ios/issues/1959).

Changes in MatrixKit in 0.8.1 (2018-08-17)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.1).

Changes in MatrixKit in 0.8.0 (2018-08-10)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.11.0).
 * MXKRoomDataSource: Add send reply with text message (vector-im/riot-ios#1911).
 * MXKSessionRecentsDataSource: Hide rooms that should not be displayed to user (linked to vector-im/riot-ios#1938).
 * MXKRoomDataSource: Fix a multithreading issue that caused a crash (PR #456).
 
Bug fix:
 * MXKSampleJSQMessagesViewController: Fix room display assertion when user has no display name.

API break:
 * MXKContactManager: Remove the privateMatrixContacts method.
 * MXKSearchCellDataStoring: Replace initWithSearchResult by async cellDataWithSearchResult.
 * MXKRoomDataSourceManager: The roomDataSourceForRoom method is now asynchronous.
 * MXKRoomDataSourceManager: closeRoomDataSource has been replaced by closeRoomDataSourceWithRoomId.

Changes in MatrixKit in 0.7.15 (2018-07-03)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.12).
 * MXKWebViewVC: enableDebug: support multiple parameters in console.* logs methods.
 * Add MXKBarButtonItem, UIBarButtonItem subclass with convenient action block.
 * MXKRoomDataSource: Make processingQueue public so that overidding class can use it.
 * MXKRoomBubbleCellData: add a readReceipts member to cache read receipts data.
 
Bug fix:

API break:
 
Changes in MatrixKit in 0.7.14 (2018-06-01)
==========================================

Improvements:
 * MXKAccountManager: Add a removeAccount method with a sendLogoutRequest parameter.
 
Bug fix:
 * MXKWebViewVC: Fix crash with WKWebView and enableDebug

Changes in MatrixKit in 0.7.13 (2018-05-31)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.11).
 * MXKWebViewVC: Replace UIWebView by WKWebview.
 * Add convenient error screen display.
 
Bug fix:
 * Quotes (by themselves) render as white blocks (vector-im/riot-ios#1877).
 
API break:
 * MXKWebViewVC uses now a WKWebview.

Changes in MatrixKit in 0.7.12 (2018-05-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.10).
 * Display quick replies in timeline (vector-im/riot-ios#1858).
 * Send Stickers: Manage local echo for sticker (vector-im/riot-ios#1860).
 * Regex optimisation: Cache regex to find all HTML tags.
 * Regex optimisation: Cache NSDataDetector to find links.
 * MXKWebViewViewController: add `enableDebug` to help to debug embedded javascript.
 
Bug fix:
 * HTML Rendering: Fix the display of side borders of HTML blockquotes (vector-im/riot-ios#1857).

Changes in MatrixKit in 0.7.11 (2018-04-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.9).
 
Bug fix:
 * Regression: Sending a photo from the photo library causes a crash.

Changes in MatrixKit in 0.7.10 (2018-04-20)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.8).
 * Render stickers in the timeline (vector-im/riot-ios#1819).
 * Improve Error Notifications (vector-im/riot-ios#1839).
 
Bug fix:
 * Crash on URL like https://riot.im/#/app/register?hs_url=... (vector-im/riot-ios#1838).
 
Changes in MatrixKit in 0.7.9 (2018-03-30)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.7).

Changes in MatrixKit in 0.7.8 (2018-03-12)
==========================================

Bug fix:
 * Groups: Room summary should not display notices about groups (vector-im/riot-ios#1780).
 * MXKEventFormatter: Emotes which contain a single emoji are expanded to be enormous (vector-im/riot-ios#1558).

Changes in MatrixKit in 0.7.7 (2018-02-27)
==========================================

Bug fix:
 * My communities screen is empty despite me being in several groups (vector-im/riot-ios#1792).

Changes in MatrixKit in 0.7.6 (2018-02-14)
==========================================

Improvement:
 * Flair handling - MXKRoomDataSource: Wait for the session to be running before refreshing the related groups (PR #401).

Changes in MatrixKit in 0.7.5 (2018-02-09)
==========================================

Improvements:
 * Add MXKSessionGroupDataSource: basic class to handle the groups of a matrix session.
 * Add MXKGroupListViewController: basic view controller used to list the user's groups.
 * Groups: Display flair for users in room history. (vector-im/riot-meta#118).
 * MXKEventFormatter: Treat the matrix group ids as link.
 
Bug fixes:
 * iPhone X: room messages overlap the room activity view (vector-im/riot-ios#1754).

API breaks:
 * MXKEventFormater: Move into MXKTools the methods used to process html content (PR #392).

Translations:
  * Catalan (6%), added thanks to @sim6 and @salvadorpla (PR #397).

Changes in MatrixKit in 0.7.4 (2017-12-27)
==========================================

Bug fixes:
 * Silent crash at startup in [MXKContactManager loadCachedMatrixContacts] (https://github.com/vector-im/riot-ios#1711).
 * Should fix missing push notifications (https://github.com/vector-im/riot-ios/issues/1696).
 * Should fix the application crash on "Failed to grow buffer" when loading local phonebook contacts (https://github.com/matrix-org/riot-ios-rageshakes/issues/779).

Changes in MatrixKit in 0.7.3 (2017-11-30)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.4).
 * MXKEncryptionInfoView: add encryptionInfoViewDidClose.

Bug fixes:
 * Failed to send photos which are not stored on the local device and must be downloaded from iCloud (vector-im/riot-ios#1654).
 * App crashes when user wants to share a message (matrix-org/riot-ios-rageshakes#676).
 * Wrong bubble layout after an image redaction (#380).
 
API breaks:
 * MXKRoomInputToolbarView: `roomInputToolbarView:sendImage:withMimeType:` method considers the full-sized image data instead of the local image URL.
 * MXKRoomInputToolbarView: `sendSelectedImage:withCompressionMode:andLocalURL:` is replaced with `sendSelectedImage:withMimeType:andCompressionMode:isPhotoLibraryAsset:`.
 * MXKRoomDataSource: `sendImage:mimeType:success:failure:` method considers the full-sized image data instead of the local image URL.
 
Translations:
  * Vietnamese (100%), added thanks to @loulsle (PR #381).
  * Japanese (5.2%), updated thanks to @libraryxhime (PR #381).

Changes in MatrixKit in 0.7.2 (2017-11-13)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.3).

Bug fixes:
 * Share silently fails on big pics - eg panoramas (vector-im/riot-ios#1627).

Changes in MatrixKit in 0.7.1 (2017-10-27)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.1).

Changes in MatrixKit in 0.7.0 (2017-10-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.10.0).
 * Support Callkit and PushKit.
 * Remove NULL bytes from text messages, thanks to @spantaleev (PR #364).
 * Add generic annotations for MXKAccountManager, thanks to @morozkin (PR #371).

Bug fixes:
 * Once I changed my room title it is not updating in the room (vector-im/riot-ios#1569).
 * Wrong paragraph rendering in the room messages (vector-im/riot-ios#1500).
 * MXKInterleavedRecentsDataSource: Fix crash (matrix-org/riot-ios-rageshakes#483).

Changes in MatrixKit in 0.6.3 (2017-10-03)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.9.3).
 * Add showDecryptedContentInNotifications property to MXKAccount, thanks to @morozkin (PR #351).
 * Add incoming calls view, thanks to @morozkin (PR #352).
 * MXKAppSettings: Add addSupportedEventTypes and removeSupportedEventTypes (PR #354).
 * Add a back button in the attachments viewer (PR #356).
 * Fix iOS11 disruption (PR #361).

Bug fixes:
 * Fix inbound video calls don't have speakerphone turned on by default (vector-im/riot-ios#933), thanks to @morozkin (PR #353).
 * Fix garbled HTML paragraph syntax during markdown conversion, thanks to @spantaleev (PR #355).
 * Crash in [MXKAttachmentInteractionController finishInteractiveTransition] (PR #358).
 * Riot on iOS11 sends images as HEIC format, which nothing else can display (PR #359).
 * Device name leaks personal information (vector-im/riot-ios#910).
 
Translations:
  * Basque, updated thanks to @osoitz (PR #360).
  * French, updated thanks to @zecakeh (PR #363).

Changes in MatrixKit in 0.6.2 (2017-08-25)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.9.2).
 * Support App Extension, thanks to @aramsargsyan (#336).
 * MXKAppSettings: Add a userDefaults object shared within the application group.
 * Dark Theme support - MXKView: a new base class to add some functionalities to the UIView (#339).
 * Dark Theme support - MXKTableViewCell/MXKCollectionViewCell: support customization when the view is initialized or prepared for reuse (#339).
 * Dark Theme support - MXKRoomViewController: support the customization of the event details view (#343).
 * MXKPieChartHUD: a new class based on MXKPieChartView used to display pie chart HUDs, thanks to @aramsargsyan (#346).
 * MXKAccountManager: Add a method to reload existing accounts from the local storage.
 
Translations:
  * Basque, thanks to @osoitz (PR #348).

Changes in MatrixKit in 0.6.1 (2017-08-08)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.9.1).
 * MXKEventFormatter: Add emojiOnlyTextFont property to special case the display of message containing only emojis.

Bug fixes:
 * Fix problem with dismissing of MXCallViewController (https://github.com/vector-im/riot-ios/issues/1405), thanks to @morozkin (#342).
 
Changes in MatrixKit in 0.6.0 (2017-08-01)
==========================================

Improvements:
 * Minimum target is now iOS 8.0.
 * Upgrade MatrixSDK version (v0.9.0).
 * MXKRoomViewController: Merge of membership events (MELS).
 * Translation: Add NSBundle+MXKLanguage to change language at runtime and define a fallback language for missing translations.
 * New MXKLanguagePickerViewController screen to select a language.
 * MXKEventFormatter: Add singleEmojiTextFont property to special case the display of message with a single emoji (https://github.com/vector-im/riot-ios#1157).
 * Add the m.audio attachments support (https://github.com/vector-im/riot-ios#1102).
 * Remove MXKAlert, use UIAlertViewController instead.
 * MXKRoomBubbleCellDataStoring: Add the tag property.
 * App Extension support: wrap access to the UIApplication shared instance.

Translations:
 * Dutch, thanks to @nvbln (PR #318).
 * German, thanks to @krombel, @esackbauer, @Bamstam.
 * French, thanks to @krombel, @kaiyou, @babolivier and @bestspyever.
 * Russian, thanks to @gabrin, @Andrey and @shvchk.
 * Simplified Chinese, thanks to @tonghuix.
 * Latvian, thanks to @lauris79.

Bug fixes:
 * Chat screen: the sender avatar is missing (https://github.com/vector-im/riot-ios#1361).
 * MXKEventFormatter: Fix URLs with 2 hashes create wrong links (https://github.com/vector-im/riot-ios#1365).
 * Room with no icon ended up with the icon of a different room.

Changes in MatrixKit in 0.5.2 (2017-06-30)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.8.2).
 * Add read receipts details screen, thanks to @aramsargsyan (PR #310).

Bug fixes:
 * Chat screen: the sender avatar is missing (https://github.com/vector-im/riot-ios#1361).
 * MXKEventFormatter: Fix URLs with 2 hashes create wrong links (https://github.com/vector-im/riot-ios#1365).
 * Room with no icon ended up with the icon of a different room.

Changes in MatrixKit in 0.5.1 (2017-06-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.8.1).
 * MXCallViewController: Add waiting status string for MXCallViewController, thanks @morozkin.
 * Add MXKSoundPlayer to handle app sounds, thanks to @morozkin (PR #306 #307).

Bug fixes:
 * MXKRoomDataSourceManager: Do not accept call of roomDataSourceForRoom with roomId = nil.
 * Home: Tapping on an unread room on home page takes you to the wrong room (https://github.com/vector-im/riot-ios#1304).
 * Member page: empty items (vector-im/riot-ios#1323).

Changes in MatrixKit in 0.5.0 (2017-06-16)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.8.0).
 * Add read markers synchronisation across matrix clients.
 * Add support of MXRoomSummary.
 * Add directory server list data model (datasource, cellDataStoring protocol and its minimal implementation).
 * Add viewcontroller interactive animations to quit attachment viewer, thanks to @aramsargsyan (PR #259).
 * MXKRecentsViewController: Update the pull to kick mechanism to take into account some recents table view settings (used in inherited class).
 * MXKRecentListViewController: Add `hideSearchBar:` method.
 * MXKRecentsDataSource: Expose the current search pattern list to the inherited classes.
 * Chat screen: Recognise and make tappable phone numbers, address, etc.
 * Call: Play the right sounds during call life, thanks to @morozkin (PR #298) (https://github.com/vector-im/riot-ios/issues/1101).
 * Documentation: Updated example to display Recents List with correct datasource class, thanks to javierquevedo (PR #278).
 * Pods: Use bundle ressource to store assets, thanks to Samuel Gallet (PR #279).
 * Pods: Clean headers to be able to build MatrixKit pod as a module, thanks to Samuel Gallet (PR #282) and @morozkin (PR #286).
 
Bug fixes:
 * Bug Fix: App crashes when the attachments viewer is closed from an animated gif (#262).
 * Chat screen: the navigation bar is missing after closing the attachments viewer (#264).
 * Attachments viewer: Wrong attachment is displayed after screen rotation.
 * App crashes after using the attachment viewer (https://github.com/vector-im/riot-ios#1143).
 * App crashes when the user selects a picture from the FILES tab of the room settings (https://github.com/vector-im/riot-ios#1147).
 * When bringing the app up again it freezes for about 5s before a loading wheel appears (https://github.com/vector-im/riot-ios#1213).
 * Contacts picker: Local contacts are missing sometimes.
 * MXKAlert: Prevent MXKAlert from being retained in action handler, thanks to @morozkin (PR #287).
 * Photo selection and sending crash (https://github.com/vector-im/riot-ios#1025).
 * A permalink is positioned off the screen (https://github.com/vector-im/riot-ios#553).

Changes in MatrixKit in 0.4.11 (2017-03-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.11).
 
Bug fixes:
 * Chat screen: image thumbnails management is broken (https://github.com/vector-im/riot-ios#1121).
 * Image viewer repeatedly loses overlay menu (https://github.com/vector-im/riot-ios#1109).

Changes in MatrixKit in 0.4.10 (2017-03-21)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.10).

Changes in MatrixKit in 0.4.9 (2017-03-16)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.9).
 
Bug fixes:
 * Riot user created without msisdn in his settings (https://github.com/vector-im/riot-ios#1103).

Changes in MatrixKit in 0.4.8 (2017-03-10)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.8).
 * MXKRoomActivitiesView: Manage room activities view height changes.
 * Crypto - Warn unknown devices: treat MXDeviceUnknown as MXDeviceUnverified.
 * Crypto: Add MXKEncryptionInfoViewDelegate to be notified when the device has been verified.
 * Crypto: Reset devices keys when clearing app cache in order to fix UISIs received by other people.
 * Add MXKCountryPickerViewController.
 * MXKContactManager: Reload the local contacts from the system when the user changes his mind and disables the contact sync.
 * MXKAccount: List the phone numbers linked to the account.
 * MXKAccount: add warnedAboutEncryption property.
 * MXK3PID: Support phone number validation.
 * CommonMark: Replace GHMarkdownParser with cmark.
 * MXKAuthInputsPasswordBasedView: Suport the new Login API with different types of identifiers.
 * MXKContactManager: Discover matrix users by using the local phonebook entries (email and phone number) (https://github.com/vector-im/riot-ios#904).
 
Bug fixes:
 * Self-signed homeserver: Moved the code that trusts already trusted certificate into MXRestClient (Related to https://github.com/matrix-org/matrix-ios-sdk/pull/248).
 * MXKAuthenticationViewController: Fix notification loop on server error.
 
API breaks:
  * MXKAuthInputsViewDelegate: [authInputsViewEmailValidationRestClient:] has been renamed to [authInputsViewThirdPartyIdValidationRestClient:].
  * MXKDeviceView: [deviceViewDidUpdate:] has been renamed to [dismissDeviceView: didUpdate:].

Changes in MatrixKit in 0.4.7 (2017-02-08)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.7).
 * Add E2E keys export & import. This is managed by new MXKEncryptionKeysImportView and MXKEncryptionKeysExportView views.
 * Show riot enabled local contacts in known contacts too (https://github.com/vector-im/riot-ios#1001).
 
Bug fixes:
 * Duplicated msg when going into room details (https://github.com/vector-im/riot-ios#970).
 * Local echoes for typed messages stay (far) longer in grey (https://github.com/vector-im/riot-ios#1007).
 * Should fix crash in 0.3.8: [MXKRoomInputToolbarView contentEditingInputsForAssets:withResult:onComplete:] (https://github.com/vector-im/riot-ios#1015).
 
Changes in MatrixKit in 0.4.6 (2017-01-24)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.6).
 * MXKContactManager: Support bulk lookup to discover the matrix users in local contacts.
 * MXKContactTableCell: Let contacts table refresh matrix ids of the local contacts.
 
Bug fixes:
 * Bug Fix: App is stuck on logout when device is offline (https://github.com/vector-im/riot-ios#963).

Changes in MatrixKit in 0.4.5 (2017-01-19)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.5).
 * View controller: Remove properties initialization from `viewDidLoad` (#94)
 * MXKContact: Add [initContactWithDisplayName:emails:phoneNumbers:andThumbnail:] method.
 * MXKContactManager: Add API to sort a contacts array.
 * MXKContactManager: Add `localContactsSplittedbyContactMethod` property, the contacts list obtained by splitting each local contact by contact method.
 
Bug fixes:
 * Cloned rooms in rooms list (vector-im/riot-ios#889).
 * Riot looks to me like I'm sending the same message twice (vector-im/riot-ios#894).
 * matrix.to links containing room ids are not hyperlinked (vector-im/riot-ios#886).
 * Integer negative wraparound in upload progress meter (vector-im/riot-ios#892).
 * MXKRoomBubbleTableViewCell: a square avatar has been observed.
 * MXKContact: Encode the thumbnail of the local contacts.

API breaks:
 * MXKContactManager: Replace `localEmailContacts:` with `localContactsWithMethods:` to list the local contacts who have contact methods which may be used to invite them or to discover matrix users.

Changes in MatrixKit in 0.4.4 (2016-12-23)
==========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.4).
 * Crypto: add MXKDeviceView and MXKEncryptionInfoView to display device or encryption information.
 * Crypto: Improve decryption error messages (specially for unknown inbound session id).
 * MXKEventFormatter: add encryptingTextColor settings property.
 
Bug fixes:
 * Voip : decline call when room opened freeze riot (https://github.com/vector-im/vector-ios#764).

API breaks:
 * MXKCallViewController: remove `isPresented` property.
 * Move MXKMediaManager and MXKMediaLoader at SDK level.
 * Move MXEncryptedAttachments to SDK level.
 * Move outgoing messages management to SDK level.

Changes in MatrixKit in 0.4.3 (2016-11-23)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.3).
 
Bug fixes:
 * Typing indicator should stop when the user sends his message (https://github.com/vector-im/vector-ios#809).
 * Crypto: Made attachments work better cross platform.

Changes in MatrixKit in 0.4.2 (2016-11-22)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.2).
 * MXKAccount: Add API to handle account device information.
 
Bug fixes:
 * Crypto: Do not allow to redact the event that enabled encryption in a room.

Changes in MatrixKit in 0.4.1 (2016-11-18)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.1).
 
Bug fixes:
 * Make share/save/copy work for e2e attachments.
 * Fix a random crash when uploading an e2e attachment.
 * Wrong thumbnail shown whilst uploading e2e image  (https://github.com/vector-im/vector-ios#795).

Changes in MatrixKit in 0.4.0 (2016-11-17)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.7.0).
 * Support end-to-end encryption.
 * Chat history: Display a message for `m.room.encryption` events.
 * MXKAccount: Logout properly by invalidating the access token.
 * Tag explicitly the invite as DM or not DM (https://github.com/vector-im/vector-ios/issues/714).
 * MXKRecentListViewController: Reload the table view on the direct rooms update (https://github.com/vector-im/vector-ios/issues/715).
 * MXKAttachment: Generate thumbnail URL.
 * MXKRoomDataSource: Create and upload thumbnails for encrypted images.
 
 API break:
 * MXKEventFormatter: remove `fakeRoomMessageEventForRoomId` API (temporary events are now created by MXRoom class).
 
 Bug fixes:
 * Use `contains_url` filter during the attachments search (https://github.com/vector-im/vector-ios/issues/652).
 * MXKRoomDataSource: infinite loop on empty bubbles array.
 * MXKRoomInputToolbarView: Disable view animation during text reset to prevent placeholder distorsion.
 * Fix for accepting autocorrect on message send.
 * MXKRoomBubbleCellData: Should fix the text bubbles overlapping.

Changes in MatrixKit in 0.3.19 (2016-09-30)
===========================================
 
 Bug fixes:
 * App crashes when user taps on room alias with multiple # in chat history (https://github.com/vector-im/vector-ios/issues/668).
 * Room message search: the search pattern is not highlighted in results (https://github.com/vector-im/vector-ios/issues/660).

Changes in MatrixKit in 0.3.18 (2016-09-27)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.17).
 * MXKCallViewController: Hide camera switch on voice call.
 
 Bug fixes:
 * No ringback tones when placing voice calls in silent mode (https://github.com/vector-im/vector-ios/issues/631).
 * Going back into a VC from back-to-app takes the call off speakerphone (https://github.com/vector-im/vector-ios/issues/581).
 * Transparent png avatars are shown on black rather than white bg when RRs (https://github.com/vector-im/vector-ios/issues/639).
 * iOS cannot play videos sent from web (https://github.com/vector-im/vector-ios/issues/640).
 * MXKPieChartView: The background view is not reset on background color (unprogressColor) change.
 * MXKEventFormatter: The invitation rejection was not displayed.
 * The room preview does not always display the right member info (https://github.com/vector-im/vector-ios/issues/643).

Changes in MatrixKit in 0.3.17 (2016-09-15)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.16).
 * MXKCallViewController: For 1:1 call, display the other peer information instead of the room information.
 
 Bug fixes:
 * Chat screen: unexpected scroll up on new sent messages (https://github.com/vector-im/vector-ios/issues/600).

Changes in MatrixKit in 0.3.16 (2016-09-08)
===========================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.14).
 * Hyperlink mxids and room aliases  (https://github.com/vector-im/vector-ios/issues/442).
 * Handle 404 (Event not found) on permalinks (https://github.com/vector-im/vector-ios/issues/484).
 * MXKRoomDataSourceManager: Add API to mark all messages as read (https://github.com/vector-im/vector-ios/issues/442).
 * Chat screen: New message(s) notification (https://github.com/vector-im/vector-ios/issues/532).
 * MXKCallViewController: support custom audio sounds.
 * MXKRoomInputToolbarView: Expose the becomeFirstResponder method.
 * MXKRoomViewController: expose showEventDetails method.
 * MXKEventFormatted: Save 2 seconds on app startup when a last message is a HTLM code block.
 * MXKRoomDataSourceManager: Add missedHighlightDiscussionsCount method (https://github.com/vector-im/vector-ios/issues/563).
 * MXKContactManager: Expose the current list of the contacts for whom a 1:1 room exists (https://github.com/vector-im/vector-ios/issues/529).
 * MXKEventFormatter: Until e2e is impl'd, encrypted msgs should be shown in the UI as unencryptable warning text (https://github.com/vector-im/vector-ios/issues/559).
 * MXKEventFormatter: Change how the kick reason is displayed (https://github.com/vector-im/vector-ios/issues/549).

Bug fixes:
 * Room Settings: some addresses are missing (https://github.com/vector-im/vector-ios/issues/528).
 * Sync has got stuck while the app was backgrounded (https://github.com/vector-im/vector-ios/issues/506).
 * Chat screen: wrong attachment is opened (https://github.com/vector-im/vector-ios/issues/387).
 * Chat screen: mention the member name at the cursor position (not a the end) (https://github.com/vector-im/vector-ios/issues/issues/385).
 * Chat screen: Add feedback when user clicks on attached files (https://github.com/vector-im/vector-ios/issues/534).
 * MXKTableViewCellWithLabelAndTextField: Label is cropped when text field value is too long.
 * Attachment viewer: Video controls are buggy (https://github.com/vector-im/vector-ios/issues/460).
 * Preview on world readable room failed.  (https://github.com/vector-im/vector-ios/issues/556).
 * Vector automatically marks incoming messages as read in background (https://github.com/vector-im/vector-ios/issues/558).
 * Call Locking phone whilst setting up a call interrupts the call setup (https://github.com/vector-im/vector-ios/issues/161).

Changes in MatrixKit in 0.3.15 (2016-08-25)
===============================================

Bug fixes:
 * Fix crash in recents screen.

Changes in MatrixKit in 0.3.14 (2016-08-25)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.13).
 * MXCallViewController: Add conference call support.
 * MXCallViewController: Add camera switch.
 * MXKRoomInputToolbarView: Manage sending of a multiselection of media (https://github.com/vector-im/vector-ios/301).
 * MXKRoomSettingsViewController: increase section header height.

Bug fixes:
 * Redacting membership events should immediately reset the displayname & avatar of room members (https://github.com/vector-im/vector-ios/issues/443).
 * Profile changes shouldn't reorder the room list (https://github.com/vector-im/vector-ios/issues/494).
 * When the last message is redacted, [MXKRecentCellData update] makes paginations loops (https://github.com/vector-im/vector-ios/issues/520).
 * Call: the remote and local video are not scaled to fill the video container (https://github.com/vector-im/vector-ios/issues/537).
 * Call: Screen still tries to turn off when on a VC (https://github.com/vector-im/vector-ios/issues/521).
 * Call: Do not vibrate when outgoing call is placed.
 * The message displayed in a room when a 3pid invited user has registered is not clear (https://github.com/vector-im/vector-ios/issues/74).
 
Changes in MatrixKit in 0.3.13 (2016-08-01)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.12).
 * MXTools: Added methods to check media access permissions like Camera or Microphone.
 * MXCallViewController: Check permissions before accessing the microphone or the camera.

Bug fixes:
 * Vector is turning off my music now that VoIP is implemented (https://github.com/vector-im/vector-ios/476)
 
Changes in MatrixKit in 0.3.12 (2016-07-26)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.11).

Bug fixes:
 * Confirmation prompt before opping someone to same power level (https://github.com/vector-im/vector-ios/issues/461).
 * Fixed string displayed on outgoing video call (it said "xxx placed a voice call)
 * Room Settings: The room privacy setting text doesn't fit in phone mode (https://github.com/vector-im/vector-ios/issues/429).

Changes in MatrixKit in 0.3.11 (2016-07-15)
===============================================

Improvements:
 * Upgrade MatrixSDK version (v0.6.10).
 * MXKRoomDataSource: Display room history visibility changes.
 * MXKEventFormatter: Add the defaultCSS property to enrich the defaultCSS used by DTCoreText.
 * MatrixKitTests: Create first MatrixKit unitary test.

Bug fixes:
 * Markdown swallows leading #'s even if there are less than 3 (https://github.com/vector-im/vector-ios/issues/423).
 * Fix the rendering of <code> tags: line breaks are kept, the Menlo font is used with a light grey background.
 * HTML blockquote is badly rendered: some characters can miss (https://github.com/vector-im/vector-ios/issues/437).
 * MXKRoomSettingsViewController: Infinite loading wheel on bad network.
 * MXKEventFormatter - Fix crash on NSConcreteMutableAttributedString initWithString:: nil value.

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
 
