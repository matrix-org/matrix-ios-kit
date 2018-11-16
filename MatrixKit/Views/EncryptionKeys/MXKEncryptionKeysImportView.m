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
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;
        
        _alertController = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_import_room_keys"] message:[NSBundle mxk_localizedStringForKey:@"e2e_import_prompt"] preferredStyle:UIAlertControllerStyleAlert];
    }
    return self;
}

- (void)showInViewController:(MXKViewController*)mxkViewController toImportKeys:(NSURL*)fileURL onComplete:(void(^)(void))onComplete
{
    __weak typeof(self) weakSelf = self;

    // Finalise the dialog
    [_alertController addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.secureTextEntry = YES;
         textField.placeholder = [NSBundle mxk_localizedStringForKey:@"e2e_passphrase_enter"];
         [textField resignFirstResponder];
     }];
    
    [_alertController addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               onComplete();
                                                           }
                                                           
                                                       }]];
    
    [_alertController addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"e2e_import"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               // Retrieve the password
                                                               UITextField *textField = [self.alertController textFields].firstObject;
                                                               NSString *password = textField.text;
                                                               
                                                               // Start the import process
                                                               [mxkViewController startActivityIndicator];
                                                               [self->mxSession.crypto importRoomKeys:[NSData dataWithContentsOfURL:fileURL] withPassword:password success:^(NSUInteger total, NSUInteger imported) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       [mxkViewController stopActivityIndicator];
                                                                       onComplete();
                                                                   }
                                                                   
                                                               } failure:^(NSError *error) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       [mxkViewController stopActivityIndicator];
                                                                       
                                                                       // TODO: i18n the error
                                                                       UIAlertController *otherAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                                                                       
                                                                       [otherAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                           
                                                                           if (weakSelf)
                                                                           {
                                                                               onComplete();
                                                                           }
                                                                           
                                                                       }]];
                                                                       
                                                                       [mxkViewController presentViewController:otherAlert animated:YES completion:nil];                                                                       
                                                                   }
                                                                   
                                                               }];
                                                           }
                                                           
                                                       }]];

    // And show it
    [mxkViewController presentViewController:_alertController animated:YES completion:nil];
}

@end
