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

#import "MXKEncryptionKeysExportView.h"

#import "MXKViewController.h"
#import "MXKRoomDataSource.h"
#import "NSBundle+MatrixKit.h"

#import <MatrixSDK/MatrixSDK.h>

@interface MXKEncryptionKeysExportView ()
{
    MXSession *mxSession;
}

@end

@implementation MXKEncryptionKeysExportView

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    // Reuse MXKAlert dialog
    self = [super initWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_export_room_keys"]
                        message:[NSBundle mxk_localizedStringForKey:@"e2e_export_prompt"]
                          style:MXKAlertStyleAlert];

    if (self)
    {
        mxSession = matrixSession;
    }
    return self;
}


- (void)showInViewController:(MXKViewController *)mxkViewController toExportKeysToFile:(NSURL *)keyFile onComplete:(void (^)(BOOL success))onComplete
{
    __weak typeof(self) weakSelf = self;

    // Finalise the dialog
    [self addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.secureTextEntry = YES;
         textField.placeholder = [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_enter"];
         [textField resignFirstResponder];
     }];

    [self addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.secureTextEntry = YES;
         textField.placeholder = [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_confirm"];
         [textField resignFirstResponder];
     }];

    self.cancelButtonIndex = [self addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                              {
                                  if (weakSelf)
                                  {
                                      onComplete(NO);
                                  }
                              }];

    [self addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_export"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
     {
         if (weakSelf)
         {
             typeof(self) self = weakSelf;

             // Retrieve the password and confirmation
             UITextField *textField = [self textFieldAtIndex:0];
             NSString *password = textField.text;

             textField = [self textFieldAtIndex:1];
             NSString *confirmation = textField.text;

             // Check they are valid
             if (password.length == 0 || ![password isEqualToString:confirmation])
             {
                 NSString *error = password.length ? [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_not_match"] : [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_empty"];

                 MXKAlert *otherAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:error style:MXKAlertStyleAlert];

                 otherAlert.cancelButtonIndex = [otherAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

                     if (weakSelf)
                     {
                        onComplete(NO);
                     }
                 }];

                 [otherAlert showInViewController:mxkViewController];
             }
             else
             {
                 // Start the export process
                 [mxkViewController startActivityIndicator];

                 [self->mxSession.crypto exportRoomKeysWithPassword:password success:^(NSData *keyFileData) {

                     if (weakSelf)
                     {
                        [mxkViewController stopActivityIndicator];

                        // Write the result to the passed file
                        [keyFileData writeToURL:keyFile atomically:YES];
                         onComplete(YES);
                     }

                 } failure:^(NSError *error) {

                     if (weakSelf)
                     {
                         [mxkViewController stopActivityIndicator];
                     
                         // TODO: i18n the error
                         MXKAlert *otherAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:error.localizedDescription style:MXKAlertStyleAlert];
                         
                         otherAlert.cancelButtonIndex = [otherAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                             
                             onComplete(NO);
                         }];
                         
                         [otherAlert showInViewController:mxkViewController];
                     }
                 }];
             }
         }
     }];
    
    // And show it
    [self showInViewController:mxkViewController];
}


@end

