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

#import <UIKit/UIKit.h>

#import <AddressBook/AddressBook.h>

#import "MXKCellData.h"

#import "MXKEmail.h"
#import "MXKPhoneNumber.h"

/**
 Posted when the contact thumbnail is updated.
 The notification object is a contact Id.
 */
extern NSString *const kMXKContactThumbnailUpdateNotification;

@interface MXKContact : MXKCellData <NSCoding>

/**
 The unique identifier
 */
@property (nonatomic, readonly) NSString * contactID;

/**
 The display name
 */
@property (nonatomic, readwrite) NSString *displayName;

/**
 The contact thumbnail. Default size: 256 X 256 pixels
 */
@property (nonatomic, copy, readonly) UIImage *thumbnail;

/**
 YES if the contact does not exist in the contacts book
 the contact has been created from a MXUser
 */
@property (nonatomic, readonly) BOOL isMatrixContact;

/**
 The array of MXKPhoneNumber
 */
@property (nonatomic, readonly) NSArray *phoneNumbers;

/**
 The array of MXKEmail
 */
@property (nonatomic, readonly) NSArray *emailAddresses;

/**
 The array of matrix identifiers
 */
@property (nonatomic, readonly) NSArray* matrixIdentifiers;

/**
 The contact ID from native phonebook record
 */
+ (NSString*)contactID:(ABRecordRef)record;

/**
 Create a contact from a local contact
 
 @param record local contact id
 @return MXKContact instance
 */
- (id)initWithABRecord:(ABRecordRef)record;

/**
 Create a contact with the dedicated info
 
 @param displayName
 @param matrixID
 @return MXKContact instance
 */
- (id)initWithDisplayName:(NSString*)displayName matrixID:(NSString*)matrixID;

/**
 The contact thumbnail with a prefered size.
 
 If the thumbnail is already loaded, this method returns this one by ignoring prefered size.
 The prefered size is used only if a server request is required.
 
 @return thumbnail with a prefered size
 */
- (UIImage*)thumbnailWithPreferedSize:(CGSize)size;

/**
 Check if the patterns can match with this contact
 */
- (BOOL) matchedWithPatterns:(NSArray*)patterns;

/**
 Internationalize the contact phonenumbers
 */
- (void)internationalizePhonenumbers:(NSString*)countryCode;

@end