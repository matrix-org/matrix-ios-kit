/*
 Copyright 2018 New Vector Ltd
 
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

#import <XCTest/XCTest.h>
#import <MatrixSDK/MatrixSDK.h>

#pragma mark - MXFileStore Private Interface

@interface MXFileStore (Testing)
- (BOOL)storeReceipts:(NSArray<MXReceiptData*>*)receipts inRoom:(NSString*)roomId;
- (void)saveReceiptsWithCompletion:(void (^)(void))completion;
@end

#pragma mark - Defines & Constants

static NSString* const kCurrentUserId = @"unittestiuser";

static NSString* const kRoomId = @"roomid-1";
static NSString* const kFirstEventId = @"$15242573383491074EwMmI:matrix.org";
static NSString* const kLastEventId = @"$15079858922475940nSouo:matrix.org";
static NSString* const kNonExistingEventId = @"eventid-xxxxx";
static NSString* const kUserId = @"@test_one:matrix.org";


static NSString* const kSyncFileName = @"read_receipts_sync";

#pragma mark - Private Interface

@interface StorePerformanceTests : XCTestCase

@property(nonatomic, strong) NSArray<MXReceiptData*> *receipts;
@property(nonatomic, strong) NSArray<NSString*> *performanceMetrics;

@end

@implementation StorePerformanceTests

#pragma mark - Setup & Teardown

- (void)setUp
{
    [super setUp];
    
    MXRealmStore *fileStore = [self createRealmStore];
    [fileStore deleteAllData];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Properties override

- (NSArray<MXReceiptData*>*)receipts
{
    if (_receipts != nil)
    {
        return _receipts;
    }
    _receipts = [self receiptsFromFixture];
    return _receipts;
}

- (NSArray<NSString *>*)performanceMetrics
{
    return [[self class] defaultPerformanceMetrics];
}

#pragma mark - MXFileStore

- (void)testPerformanceFileStoreSaveToDiskAllReceipts
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        XCTestExpectation *testExpectation = [self expectationWithDescription:@"Save receipts"];
        
        MXFileStore *fileStore = [self createFileStore];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];
        
        [self startMeasuring];
        
        [fileStore saveReceiptsWithCompletion:^{
            [testExpectation fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:5 handler: ^(NSError *error) {
            [self stopMeasuring];
            [fileStore deleteAllData];
        }];
    }];
}

- (void)testPerformanceFileStoreSaveToDiskOneReceiptAfterAllOthers
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        XCTestExpectation *testExpectation = [self expectationWithDescription:@"Save receipts"];
        
        MXFileStore *fileStore = [self createFileStore];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];
        
        [fileStore storeReceipt:receipts.firstObject inRoom:kRoomId];
        
        [self startMeasuring];
        
        [fileStore saveReceiptsWithCompletion:^{
            [testExpectation fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:5 handler: ^(NSError *error) {
            [self stopMeasuring];
            [fileStore deleteAllData];
        }];
    }];
}

- (void)testPerformanceFileStoreWriteAllReceipts
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXFileStore *fileStore = [self createFileStore];
        
        [self startMeasuring];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];
        
        [self stopMeasuring];
        
        [fileStore deleteAllData];
    }];
}

- (void)testPerformanceFileStoreOneReceiptAfterAllOthers
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXFileStore *fileStore = [self createFileStore];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];
        
        [self startMeasuring];
        
        [fileStore storeReceipt:receipts.firstObject inRoom:kRoomId];
        
        [self stopMeasuring];
        
        [fileStore deleteAllData];
    }];
}

- (void)testPerformanceFileStoreReadReceiptsForExistingEventIdFirst
{
    MXFileStore *fileStore = [self createFileStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getEventReceipts:kRoomId eventId:kFirstEventId sorted:NO];
    }];
}

- (void)testPerformanceFileStoreReadReceiptsForExistingEventIdLast
{
    MXFileStore *fileStore = [self createFileStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getEventReceipts:kRoomId eventId:kLastEventId sorted:NO];
    }];
}

- (void)testPerformanceFileStoreReadReceiptsNonExistingEventId
{
    MXFileStore *fileStore = [self createFileStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getEventReceipts:kRoomId eventId:kNonExistingEventId sorted:NO];
    }];
}

- (void)testPerformanceFileStoreReadReceiptsForUserId
{
    MXFileStore *fileStore = [self createFileStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getReceiptInRoom:kRoomId forUserId:kUserId];
    }];
}

#pragma mark - MXRealmStore

- (void)testPerformanceRealmStoreLoadDatabase
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    MXRealmStore *fileStore = [self createRealmStore];
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXRealmFileProvider *realmFileProvider = [[MXRealmFileProvider alloc] init];
        
        [self startMeasuring];
        
        [realmFileProvider realmForUserId:kCurrentUserId];
        
        [self stopMeasuring];
    }];
}

- (void)testPerformanceRealmWriteAllReceiptsInOneTransaction
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXRealmStore *fileStore = [self createRealmStore];
        
        [self startMeasuring];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];

        [self stopMeasuring];
        
        [fileStore deleteAllData];
    }];
}

- (void)testPerformanceRealmStoreOneReceiptAfterAllOthers
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXRealmStore *fileStore = [self createRealmStore];
        
        [fileStore storeReceipts:receipts inRoom:kRoomId];
        
        [self startMeasuring];
        
        [fileStore storeReceipt:receipts.firstObject inRoom:kRoomId];
        
        [self stopMeasuring];
        
        [fileStore deleteAllData];
    }];
}



- (void)testPerformanceRealmStoreOneTransactionPerReceipt
{
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [self measureMetrics:self.performanceMetrics automaticallyStartMeasuring:NO forBlock: ^{
        
        MXRealmStore *fileStore = [self createRealmStore];
                
        [self startMeasuring];
        
        for (MXReceiptData *receiptData in receipts)
        {
            [fileStore storeReceipt:receiptData inRoom:kRoomId];
        }
        
        [self stopMeasuring];
        
        [fileStore deleteAllData];
    }];
}

- (void)testPerformanceRealmStoreReadReceiptsForExistingEventIdFirst
{
    MXRealmStore *fileStore = [self createRealmStore];

    NSArray<MXReceiptData*> *receipts = self.receipts;

    [fileStore storeReceipts:receipts inRoom:kRoomId];

    [self measureBlock:^{

        [fileStore getEventReceipts:kRoomId eventId:kFirstEventId sorted:NO];
    }];
}

- (void)testPerformanceRealmStoreReadReceiptsForExistingEventIdLast
{
    MXRealmStore *fileStore = [self createRealmStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getEventReceipts:kRoomId eventId:kLastEventId sorted:NO];
    }];
}

- (void)testPerformanceRealmStoreReadReceiptsForNonExistingEventId
{
    MXRealmStore *fileStore = [self createRealmStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getEventReceipts:kRoomId eventId:kNonExistingEventId sorted:NO];
    }];
}

- (void)testPerformanceRealmStoreReadReceiptsForUserId
{
    MXRealmStore *fileStore = [self createRealmStore];
    
    NSArray<MXReceiptData*> *receipts = self.receipts;
    
    [fileStore storeReceipts:receipts inRoom:kRoomId];
    
    [self measureBlock:^{
        
        [fileStore getReceiptInRoom:kRoomId forUserId:kUserId];
    }];
}

#pragma mark - Private

- (MXCredentials*)createTestCredentials
{
    MXCredentials *credentials = [[MXCredentials alloc] init];
    credentials.userId = kCurrentUserId;
    return credentials;
}

- (MXFileStore*)createFileStore
{
    MXCredentials *credentials = [self createTestCredentials];
    
    return [[MXFileStore alloc] initWithCredentials:credentials];
}

- (MXRealmStore*)createRealmStore
{
    MXCredentials *credentials = [self createTestCredentials];
    
    MXRealmFileProvider *realmProvider = [[MXRealmFileProvider alloc] init];
    
    return [[MXRealmStore alloc] initWithCredentials:credentials andRealmProvider:realmProvider];
}

- (NSArray<MXReceiptData*>*)receiptsFromFixture
{
    NSDictionary *json = [self jsonDictFromFile];
    MXEvent *syncevent = [MXEvent modelFromJSON:json];
    return [self receiptsFromEvent:syncevent];
}

- (NSDictionary*)jsonDictFromFile
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:kSyncFileName ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    return json;
}

- (NSArray<MXReceiptData*>*)receiptsFromEvent:(MXEvent *)event
{
    NSMutableArray *receitps = [[NSMutableArray alloc] init];
    
    NSArray<NSString*>* eventIds = [event.content allKeys];
    
    for (NSString* eventId in eventIds)
    {
        NSDictionary* eventDict = [event.content objectForKey:eventId];
        NSDictionary* readDict = [eventDict objectForKey:kMXEventTypeStringRead];
        
        if (readDict)
        {
            NSArray<NSString*>* userIds = [readDict allKeys];
            
            for (NSString* userId in userIds)
            {
                NSDictionary<NSString*, id>* params = [readDict objectForKey:userId];
                
                if ([params valueForKey:@"ts"])
                {
                    MXReceiptData* data = [[MXReceiptData alloc] init];
                    data.userId = userId;
                    data.eventId = eventId;
                    data.ts = ((NSNumber*)[params objectForKey:@"ts"]).longLongValue;
                    
                    [receitps addObject:data];
                }
            }
        }
    }
    
    return receitps;
}

@end
