/*
 Copyright 2017 Vector Creations Ltd

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
#import "MXKAlert.h"

@class MXSession, MXKViewController, MXKRoomDataSource;

/**
 `MXKEncryptionKeysExportView` is a MXKAlert dialog to export encryption keys from
 the user's crypto store.
 */
@interface MXKEncryptionKeysExportView : MXKAlert

/**
 Create the `MXKEncryptionKeysExportView` instance.

 @param mxSession the mxSession to export keys from.
 @return the newly created MXKEncryptionKeysImportView instance.
 */
- (instancetype)initWithMatrixSession:(MXSession*)mxSession;

/**
 Show the dialog in a given view controller.

 @param mxkViewController the mxkViewController where to show the dialog.
 @param keyFile the path where to export keys to.
 @param onComplete a block called when the operation is done.
 */
- (void)showInViewController:(MXKViewController*)mxkViewController toExportKeysToFile:(NSURL*)keyFile onComplete:(void(^)(BOOL success))onComplete;

@end

