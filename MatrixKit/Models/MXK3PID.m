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

#import "MXK3PID.h"

@interface MXK3PID () {
    MXRestClient *mxRestClient;
    MXHTTPOperation *currentRequest;
}
@property (nonatomic) NSString *clientSecret;
@property (nonatomic) NSUInteger sendAttempt;
@property (nonatomic) NSString *sid;
@end

@implementation MXK3PID

- (instancetype)initWithMedium:(NSString *)medium andAddress:(NSString *)address
{
    self = [super init];
    if (self)
    {
        _medium = [medium copy];
        _address = [address copy];
    }
    return self;
}

- (void)resetValidationParameters {
    _validationState = MXK3PIDAuthStateUnknown;
    
    [currentRequest cancel];
    currentRequest = nil;
    mxRestClient = nil;
    
    self.clientSecret = nil;
    self.sendAttempt = 1;
    self.sid = nil;
    // Removed potential linked userId
    self.userId = nil;
}

- (void)requestValidationTokenWithMatrixRestClient:(MXRestClient*)restClient
                                           success:(void (^)())success
                                           failure:(void (^)(NSError *error))failure {
    // Sanity Check
    if (_validationState != MXK3PIDAuthStateTokenRequested && restClient) {
        
        // Reset if the current state is different than "Unknown"
        if (_validationState != MXK3PIDAuthStateUnknown) {
            [self resetValidationParameters];
        }
        
        if ([self.medium isEqualToString:kMX3PIDMediumEmail]) {
            self.clientSecret = [MXTools generateSecret];
            _validationState = MXK3PIDAuthStateTokenRequested;
             mxRestClient = restClient;
            
            currentRequest = [mxRestClient requestEmailValidation:self.address clientSecret:self.clientSecret sendAttempt:self.sendAttempt success:^(NSString *sid) {
                _validationState = MXK3PIDAuthStateTokenReceived;
                currentRequest = nil;
                self.sid = sid;
                
                if (success) {
                    success();
                }
            } failure:^(NSError *error) {
                // Return in unknown state
                _validationState = MXK3PIDAuthStateUnknown;
                currentRequest = nil;
                // Increment attempt counter
                self.sendAttempt++;
                
                if (failure) {
                    failure (error);
                }
            }];
            
            return;
        } else if ([self.medium isEqualToString:kMX3PIDMediumMSISDN]) {
            // FIXME: support msisdn as soon as identity server supports it
            NSLog(@"[MXK3PID] requestValidationToken: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        } else {
            NSLog(@"[MXK3PID] requestValidationToken: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        }
    } else {
        NSLog(@"[MXK3PID] Failed to request validation token for 3PID: %@ (%@), state: %lu", self.address, self.medium, (unsigned long)_validationState);
    }
}

- (void)validateWithToken:(NSString*)validationToken
              success:(void (^)(BOOL success))success
              failure:(void (^)(NSError *error))failure {
    // Sanity check
    if (_validationState == MXK3PIDAuthStateTokenReceived) {
        
        if ([self.medium isEqualToString:kMX3PIDMediumEmail]) {
            _validationState = MXK3PIDAuthStateTokenSubmitted;
            
            currentRequest = [mxRestClient validateEmail:self.sid validationToken:validationToken clientSecret:self.clientSecret success:^(BOOL successFlag) {
                if (successFlag) {
                    // Validation is complete
                    _validationState = MXK3PIDAuthStateAuthenticated;
                } else {
                    // Return in previous step
                    _validationState = MXK3PIDAuthStateTokenReceived;
                }
                
                currentRequest = nil;
                
                if (success) {
                    success(successFlag);
                }
            } failure:^(NSError *error) {
                // Return in previous step
                _validationState = MXK3PIDAuthStateTokenReceived;
                currentRequest = nil;
                
                if (failure) {
                    failure (error);
                }
            }];
            
            return;
        } else if ([self.medium isEqualToString:kMX3PIDMediumMSISDN]) {
            // FIXME: support msisdn as soon as identity server supports it
            NSLog(@"[MXK3PID] validateWithToken: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        } else {
            NSLog(@"[MXK3PID] validateWithToken: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        }
    } else {
        NSLog(@"[MXK3PID] Failed to valid with token 3PID: %@ (%@), state: %lu", self.address, self.medium, (unsigned long)_validationState);
    }
    
    // Here the validation process failed
    if (failure) {
        failure (nil);
    }
}

- (void)bindWithUserId:(NSString*)userId
               success:(void (^)())success
               failure:(void (^)(NSError *error))failure {
    // Sanity check
    if (_validationState == MXK3PIDAuthStateAuthenticated) {
        
        if ([self.medium isEqualToString:kMX3PIDMediumEmail]) {
            currentRequest = [mxRestClient bind3PID:userId sid:self.sid clientSecret:self.clientSecret success:^(NSDictionary *JSONResponse) {
                // Update linked userId in 3PID
                self.userId = userId;
                currentRequest = nil;
                
                if (success) {
                    success();
                }
            } failure:^(NSError *error) {
                currentRequest = nil;
                
                if (failure) {
                    failure (error);
                }
            }];
            
            return;
        } else if ([self.medium isEqualToString:kMX3PIDMediumMSISDN]) {
            // FIXME: support msisdn as soon as identity server supports it
            NSLog(@"[MXK3PID] bindWithUserId: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        } else {
            NSLog(@"[MXK3PID] bindWithUserId: is not supported for this 3PID: %@ (%@)", self.address, self.medium);
        }
    } else {
        NSLog(@"[MXK3PID] Failed to bind 3PID: %@ (%@), state: %lu", self.address, self.medium, (unsigned long)_validationState);
    }
    
    // Here the validation process failed
    if (failure) {
        failure (nil);
    }
}

@end
