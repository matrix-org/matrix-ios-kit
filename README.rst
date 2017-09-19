MatrixKit
=========

While `MatrixSDK 
<https://github.com/matrix-org/matrix-ios-sdk>`_ provides an Objective-C API to
use the Matrix Client-Server API, MatrixKit provides a higher level, reusable
and easy-customisable UI built on top of the SDK.

Put simply, MatrixKit is a set of ViewControllers and Views. An app developer
can pick up UI components from this set and insert them into their application
storyboard or code. The end application controls what is shown when.

Each of the provided UI components has been designed to run standalone. There
are no dependencies between them.

The currently available view controllers are:

- MXKRoomViewController: shows messages of a room and allows user to chat
- MXKRecentListViewController: displays the user's rooms ordered by last
  activity
- MXKRoomMemberListViewController: a page showing the list of a room's members

Coming soon:

- Authentication views
- Public rooms: the list of public rooms
- Room creation
- Address book


Screenshots
===========

Here are two samples for displaying messages of a room:

.. image:: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKRoomViewController-w240.jpeg
    :width: 240px
    :align: left
    :target: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKRoomViewController.jpeg

.. image:: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKJSQMessagesViewController-w240.jpeg
    :width: 240px
    :align: right
    :target: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKJSQMessagesViewController.jpeg

The left one is the stock room view controller. This is the one used by `Console 
<https://itunes.apple.com/gb/app/matrix-console/id970074271?mt=8>`_ (`GitHub 
<https://github.com/matrix-org/matrix-ios-console>`_).

The right one is an override of `JSQMessagesViewController 
<https://github.com/jessesquires/JSQMessagesViewController>`_. The display is
fully managed by JSQMessagesViewController but the implementation uses data
computed by MatrixKit components: MXKRoomDataSource & MXKRoomBubbleCellData.
See the next session for definition of DataSource and celldata.


Overview
========
All view controllers in MatrixKit that display a list of items share the same
ecosystem based on 4 components:

ViewController
  The ViewController is responsible for managing the display and user actions.

DataSource
  Provides the ViewController with items (CellView objects) to display. More
  accurately, the DataSource gets data (mainly Matrix events) from the Matrix
  SDK. It asks CellData objects to process the data into human readable text and
  store it. Then, when the ViewController asks for a cellview, it renders the
  corresponding CellData into a cellview that it returns.

  For convenience, DataSources provided in MatrixKit implement
  UITableViewDataSource and UICollectionViewDataSource protocols so that
  UITableView and UICollectionView DataSources can be directly plugged to them.

CellData
  Contains data the CellView must display. There is one CellData object per
  item in the list. This is also a kind of cache to avoid displayed data needing
  to be computed everytime.

CellView
  This is an abstract object. It is often a UITableViewCellView or a
  UICollectionViewCell but can be any UIView. This is the view for an item
  displayed by the ViewController.


How to use it in your app
=========================

Installation
------------
You can embed MatrixKit to your application project with CocoaPods. The pod for
the latest MatrixKit release is::

    pod 'MatrixKit'

Use case #1: Display a screen to chat in a room
-----------------------------------------------
Suppose you have a MXSession instance stored in `mxSession` (you can learn how
to get in the Matrix SDK tutorials `here
<https://github.com/matrix-org/matrix-ios-sdk#use-case-2-get-the-rooms-the-user-has-interacted-with>`_
) and you want to chat in `#matrix:matrix.org` which room id is
`!cURbafjkfsMDVwdRDQ:matrix.org`.

You will have to instantiate a MXKRoomViewController and attach a
MXKRoomDataSource object to it. This object that will manage the room data.
This is done with the following code::

        // Create a data souce for managing data for the targeted room
        MXKRoomDataSource *roomDataSource = [[MXKRoomDataSource alloc] initWithRoomId:@"!cURbafjkfsMDVwdRDQ:matrix.org" andMatrixSession:mxSession];

        // Create the room view controller that will display it
        MXKRoomViewController *roomViewController = [[MXKRoomViewController alloc] init];
        [roomViewController displayRoom:roomDataSource];

Then, your app presents `roomViewController`. Your end user is now able to post
messages or images to the room, navigate in the history, etc.

Use case #2: Display list of user's rooms
-----------------------------------------
The approach is similar to the previous use case. You need to create a data
source and pass it to the view controller::

        // Create a data source for managing data
        MXKRecentsDataSource *recentsDataSource = [[MXKRecentsDataSource alloc] initWithMatrixSession:mxSession];

        // Create the view controller that will display it
        MXKRecentListViewController *recentListViewController = [[MXKRecentListViewController alloc] init];
        [recentListViewController displayList:recentsDataSource];


Customisation
=============

The kit has been designed so that developers can make customisations at
different levels, which are:

ViewController
  The provided ViewControllers can be subclassed in order to customise the following points:
- the CellView class used by the DataSource to render CellData.
- the layout of the table or the collection view.
- the interactions with the end user.

CellView
  The developer may override MatrixKit CellViews to completely change the way items are displayed. Note that CellView classes must be conformed to the MXKCellRendering protocol.

CellData
  The developer can implement his own CellData classes in order to prepare differently rendered data. Note that the use of customised CellData classes is handled at DataSource level (see registerCellDataClass method).

DataSource
  This object gets the data from the Matrix SDK and serves it to the view
  controller via CellView and CellData objects. You can override the default
  DataSource to have a different behaviour.


Customisation example
=====================

Use case #1: Change cells in the room chat
------------------------------------------
This use case shows how to make `cellView` customisation.

A room chat is basically a list of items where each item represents a message
(or a set of messages if they are grouped by sender). In the code, these items
are inherit from MXKTableViewCell. If you are not happy with the default
ones used by MXKRoomViewController and MXKRoomDataSource, you can change them by overriding MXKDataSourceDelegate methods in your view controller::

    - (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
    {
       // Let `MyOwnBubbleTableViewCell` class manage the display of message cells
       // This class must inherit from UITableViewCell and must conform the `MXKCellRendering` protocol
       return MyOwnBubbleTableViewCell.class;
    }
    
    - (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
    {
        // Return the `MyOwnBubbleTableViewCell` cell identifier.
        return @"MyOwnBubbleTableViewCellIdentifier";
    }
        
You may return a `cellView` class by taking into account the provided cell data. For example you can define different classes for received and sent messages.

Development
===========

If you want to help to improve MatrixKit by adding new ViewControllers, new
views, new CellViews or other improvements, this git repository contains a
sample Xcode project for demoing all reusable UI.  Please hack on the `develop`
branch and make git pull requests from it.

As its dependencies are based on CocoaPods, you will need to run `pod install`
before opening MatrixKit.xcworkspace.

Attributions
============

The filled icons play, pause, minus, back and keyboard are taken from icons8: http://icons8.com/

Copyright & License
==================

Copyright (c) 2014-2016 OpenMarket Ltd

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
