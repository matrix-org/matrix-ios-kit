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

#import "MXKEncryptionKeysImportView.h"

#import "MXKViewController.h"
#import "NSBundle+MatrixKit.h"

#import <MatrixSDK/MatrixSDK.h>

@interface MXKEncryptionKeysImportView ()
{
    MXSession *mxSession;
}

@end

@implementation MXKEncryptionKeysImportView

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    // Reuse MXKAlert dialog
    self = [super initWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_import_room_keys"]
                        message:[NSBundle mxk_localizedStringForKey:@"e2e_import_prompt"]
                          style:MXKAlertStyleAlert];

    if (self)
    {
        mxSession = matrixSession;
    }
    return self;
}

- (void)showInViewController:(MXKViewController*)mxkViewController toImportKeys:(NSURL*)fileURL onComplete:(void(^)())onComplete
{
    __weak typeof(self) weakSelf = self;

    // Finalise the dialog
    [self addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.secureTextEntry = YES;
         textField.placeholder = [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_enter"];
         [textField resignFirstResponder];
     }];

    self.cancelButtonIndex = [self addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                              {
                                  if (weakSelf)
                                  {
                                      onComplete();
                                  }
                              }];

    [self addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_import"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
     {
         if (weakSelf)
         {
             typeof(self) self = weakSelf;

             // Retrieve the password
             UITextField *textField = [self textFieldAtIndex:0];
             NSString *password = textField.text;

              __weak typeof(self) weakSelf2 = self;

             // Start the import process
             [mxkViewController startActivityIndicator];
             [self->mxSession.crypto importRoomKeys:[NSData dataWithContentsOfURL:fileURL] withPassword:password success:^{

                 if (weakSelf2)
                 {
                     [mxkViewController stopActivityIndicator];
                     onComplete();
                 }

             } failure:^(NSError *error) {

                 if (weakSelf2)
                 {
                     [mxkViewController stopActivityIndicator];

                     // TODO: i18n the error
                     MXKAlert *otherAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:error.localizedDescription style:MXKAlertStyleAlert];

                     otherAlert.cancelButtonIndex = [otherAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

                         onComplete();
                     }];

                     [otherAlert showInViewController:mxkViewController];
                 }

             }];
         }

     }];

    // And show it
    [self showInViewController:mxkViewController];
}

@end
