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

#import <Foundation/Foundation.h>
#import <MatrixSDK/MatrixSDK.h>

#import "MXKCellData.h"

/**
 `MXKDirectoryServerCellDataStoring` defines a protocol a class must conform in order to
 store room member cell data managed by `MXKDirectoryServersDataSource`.
 */
@protocol MXKDirectoryServerCellDataStoring <NSObject>

#pragma mark - Data displayed by a server cell

/**
 The name of the directory server.
 */
@property (nonatomic) NSString *desc;

/**
 The icon URL for the server.
 */
@property (nonatomic) NSString *iconUrl;

/**
 In case the cell data represents a third-party protocol instance, its description.
 */
@property (nonatomic, readonly) MXThirdPartyProtocolInstance *thirdPartyProtocolInstance;
@property (nonatomic, readonly) MXThirdPartyProtocol *thirdPartyProtocol;

/**
 Define a MXKDirectoryServerCellData that will store a third-party protocol instance.
 
 @param instance the instance of the protocol.
 @param protocol the protocol description.
 */
- (id)initWithProtocolInstance:(MXThirdPartyProtocolInstance*)instance protocol:(MXThirdPartyProtocol*)protocol;

@end
