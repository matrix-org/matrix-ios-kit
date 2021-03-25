/*
 Copyright 2016 OpenMarket Ltd

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

#import "MatrixKit.h"
#import "MXKEventFormatter+Tests.h"

@interface MXEventFormatterTests : XCTestCase
{
    MXKEventFormatter *eventFormatter;
    MXEvent *anEvent;
}

@end

@implementation MXEventFormatterTests

- (void)setUp
{
    [super setUp];

    // Create a minimal event formatter
    // Note: it may not be enough for testing all MXKEventFormatter methods
    eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:nil];

    eventFormatter.treatMatrixUserIdAsLink = YES;
    eventFormatter.treatMatrixRoomIdAsLink = YES;
    eventFormatter.treatMatrixRoomAliasAsLink = YES;
    eventFormatter.treatMatrixEventIdAsLink = YES;
    
    anEvent = [[MXEvent alloc] init];
    anEvent.roomId = @"aRoomId";
    anEvent.eventId = @"anEventId";
    anEvent.wireType = kMXEventTypeStringRoomMessage;
    anEvent.originServerTs = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);
    anEvent.wireContent = @{
                            @"msgtype": kMXMessageTypeText,
                            @"body": @"deded",
                            };
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRenderHTMLStringWithPreCode
{
    NSString *html = @"<pre><code>1\n2\n3\n4\n</code></pre>";
    NSAttributedString *as = [eventFormatter renderHTMLString:html forEvent:anEvent withRoomState:nil];

    NSString *a = as.string;

    // \R : any newlines
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\R" options:0 error:0];
    XCTAssertEqual(3, [regex numberOfMatchesInString:a options:0 range:NSMakeRange(0, a.length)], "renderHTMLString must keep line break in <pre> and <code> blocks");

    [as enumerateAttributesInRange:NSMakeRange(0, as.length) options:(0) usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

        UIFont *font = attrs[NSFontAttributeName];
        XCTAssertEqualObjects(font.fontName, @"Menlo-Regular", "The font for <pre> and <code> should be monospace");
    }];

}
    
- (void)testMarkdownFormatting
{
    NSString *html = [eventFormatter htmlStringFromMarkdownString:@"Line One.\nLine Two."];
    
    BOOL hardBreakExists =      [html rangeOfString:@"<br />"].location != NSNotFound;
    BOOL openParagraphExists =  [html rangeOfString:@"<p>"].location != NSNotFound;
    BOOL closeParagraphExists = [html rangeOfString:@"</p>"].location != NSNotFound;
    
    // Check for some known error cases
    XCTAssert(hardBreakExists, "The soft break (\\n) must be converted to a hard break (<br />).");
    XCTAssert(!openParagraphExists && !closeParagraphExists, "The html must not contain any opening or closing paragraph tags.");
}

#pragma mark - Links

- (void)testRoomAliasLink
{
    NSString *s = @"Matrix HQ room is at #matrix:matrix.org.";
    NSAttributedString *as = [eventFormatter renderString:s forEvent:anEvent];

    NSRange linkRange = [s rangeOfString:@"#matrix:matrix.org"];

    __block NSUInteger ranges = 0;
    __block BOOL linkCreated = NO;

    [as enumerateAttributesInRange:NSMakeRange(0, as.length) options:(0) usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

        ranges++;

        if (NSEqualRanges(linkRange, range))
        {
            linkCreated = (attrs[NSLinkAttributeName] != nil);
        }
    }];

    XCTAssertEqual(ranges, 3, @"A sub-component must have been found");
    XCTAssert(linkCreated, @"Link not created as expected: %@", as);
}

- (void)testLinkWithRoomAliasLink
{
    NSString *s = @"Matrix HQ room is at https://matrix.to/#/room/#matrix:matrix.org.";
    NSAttributedString *as = [eventFormatter renderString:s forEvent:anEvent];

    __block NSUInteger ranges = 0;

    [as enumerateAttributesInRange:NSMakeRange(0, as.length) options:(0) usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

        ranges++;
    }];

    XCTAssertEqual(ranges, 1, @"There should be no link in this case. We let the UI manage the link");
}

#pragma mark - Event sender/target info

- (void)testUserDisplayNameFromEventContent {
    MXEvent *event = [self eventFromJSON:@"{\"sender\":\"@alice:matrix.org\",\"content\":{\"displayname\":\"bob\",\"membership\":\"invite\"},\"origin_server_ts\":1616488993287,\"state_key\":\"@bob:matrix.org\",\"room_id\":\"!foofoofoofoofoofoo:matrix.org\",\"event_id\":\"$lGK3budX5w009ErtQwE9ZFhwyUUAV9DqEN5yb2fI4Do\",\"type\":\"m.room.member\",\"unsigned\":{}}"];
    XCTAssertEqualObjects([eventFormatter userDisplayNameFromContentInEvent:event withMembershipFilter:nil], @"bob");
    XCTAssertEqualObjects([eventFormatter userDisplayNameFromContentInEvent:event withMembershipFilter:@"invite"], @"bob");
    XCTAssertEqualObjects([eventFormatter userDisplayNameFromContentInEvent:event withMembershipFilter:@"join"], nil);
}

- (void)testUserDisplayNameFromNonMembershipEventContent {
    MXEvent *event = [self eventFromJSON:@"{\"sender\":\"@alice:matrix.org\",\"content\":{\"ciphertext\":\"foo\",\"sender_key\":\"bar\",\"device_id\":\"foobar\",\"algorithm\":\"m.megolm.v1.aes-sha2\"}},\"origin_server_ts\":1616488993287,\"state_key\":\"@bob:matrix.org\",\"room_id\":\"!foofoofoofoofoofoo:matrix.org\",\"event_id\":\"$lGK3budX5w009ErtQwE9ZFhwyUUAV9DqEN5yb2fI4Do\",\"type\":\"m.room.encrypted\",\"unsigned\":{}}"];
    XCTAssertEqualObjects([eventFormatter userDisplayNameFromContentInEvent:event withMembershipFilter:nil], nil);
    XCTAssertEqualObjects([eventFormatter userDisplayNameFromContentInEvent:event withMembershipFilter:@"join"], nil);
}

- (void)testUserAvatarUrlFromEventContent {
    MXEvent *event = [self eventFromJSON:@"{\"sender\":\"@alice:matrix.org\",\"content\":{\"displayname\":\"bob\",\"avatar_url\":\"mxc://foo.bar\",\"membership\":\"join\"},\"origin_server_ts\":1616488993287,\"state_key\":\"@bob:matrix.org\",\"room_id\":\"!foofoofoofoofoofoo:matrix.org\",\"event_id\":\"$lGK3budX5w009ErtQwE9ZFhwyUUAV9DqEN5yb2fI4Do\",\"type\":\"m.room.member\",\"unsigned\":{}}"];
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:nil], @"mxc://foo.bar");
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:@"invite"], nil);
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:@"join"], @"mxc://foo.bar");
}

- (void)testUserAvatarUrlFromEventWithNonMXCAvatarUrlContent {
    MXEvent *event = [self eventFromJSON:@"{\"sender\":\"@alice:matrix.org\",\"content\":{\"displayname\":\"bob\",\"avatar_url\":\"http://foo.bar\",\"membership\":\"join\"},\"origin_server_ts\":1616488993287,\"state_key\":\"@bob:matrix.org\",\"room_id\":\"!foofoofoofoofoofoo:matrix.org\",\"event_id\":\"$lGK3budX5w009ErtQwE9ZFhwyUUAV9DqEN5yb2fI4Do\",\"type\":\"m.room.member\",\"unsigned\":{}}"];
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:nil], nil);
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:@"invite"], nil);
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:@"join"], nil);
}

- (void)testUserAvatarUrlFromNonMembershipEventContent {
    MXEvent *event = [self eventFromJSON:@"{\"sender\":\"@alice:matrix.org\",\"content\":{\"ciphertext\":\"foo\",\"sender_key\":\"bar\",\"device_id\":\"foobar\",\"algorithm\":\"m.megolm.v1.aes-sha2\"}},\"origin_server_ts\":1616488993287,\"state_key\":\"@bob:matrix.org\",\"room_id\":\"!foofoofoofoofoofoo:matrix.org\",\"event_id\":\"$lGK3budX5w009ErtQwE9ZFhwyUUAV9DqEN5yb2fI4Do\",\"type\":\"m.room.encrypted\",\"unsigned\":{}}"];
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:nil], nil);
    XCTAssertEqualObjects([eventFormatter userAvatarUrlFromContentInEvent:event withMembershipFilter:@"join"], nil);
}

- (MXEvent *)eventFromJSON:(NSString *)json {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [MXEvent modelFromJSON:dict];
}

@end
