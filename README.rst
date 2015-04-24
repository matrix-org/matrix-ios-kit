MatrixKit
=========

While `MatrixSDK 
<https://github.com/matrix-org/matrix-ios-sdk>`_ provides an Objective-C API to use the Matrix Client-Server API, MatrixKit provides, at an higher level, reusable and easy-customisable UI built at the top of the SDK.

Basicallly, MatrixKit is a set of viewcontrollers and views. An app developer can pick up UI components from this set and insert them into their application storyboard or code. The end application plays the role of director between them.

Each of the provided UI components has been designed to run standalone. There is no depency between them.

The currently available view controllers are:

	- MXKRoomViewController: it shows messages of a room and allows user to chat
	- MXKRecentListViewController: it displays the rooms of the user ordered by their last message
	- MXKRoomMemberListViewController: a page showing the list of a room's members

Coming soon:

	- Authentification views
	- Public rooms: the list of public rooms
	- Room creation
	- Contact book
    
    
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
<https://github.com/jessesquires/JSQMessagesViewController>`_. The display is fully managed by  JSQMessagesViewController but the implemantation uses data computed by MatrixKit components: MXKRoomDataSource & MXKRoomBubbleCellData. See the next session for definition of datasource and celldata. 


Overview
========
All view controllers in MatrixKit displaying a list of items share the same ecosystem based on 4 components:

viewcontroller

  	The viewcontroller is responsible for managing the display and user actions.

datasource

 	It provides the viewcontroller with items (cellview objects) to display. More accurately, the datasource gets data(mainly Matrix events) from the Matrix SDK. It asks celldata objects to process the data into human readable text and store it. Then, when the viewcontroller asks for a cellview, it renders the corresponding celldata into a cellview that it returns.
    
 	For convenience, datasources provided in MatrixKit implement UITableViewDataSource and UICollectionViewDataSource protocols so that UITableView and UICollectionView datasources can be directly plugged to them.

celldata

     It contains data the cellview must display. There is one celldata object per item in the list. This is also a sort of cache to avoid to compute displayed data everytime.
     
cellview

     This is an abstract object. It is often a UITableViewCellView or a UICollectionViewCell but can be any UIView. This is the view for an item displayed by the viewcontroller.


How to use it in your app
=========================

Installation
------------
You can embed MatrixKit to your application project with CocoaPods. The pod for the last MatrixKit release is::

    pod 'MatrixKit'

Use case #1: Display a screen to chat in a room
-----------------------------------------------
Suppose you have a MXSession instance stored in `mxSession` (you can learn how to get in the Matrix SDK tutorials `here 
<https://github.com/matrix-org/matrix-ios-sdk#use-case-2-get-the-rooms-the-user-has-interacted-with>`_ ) and you want to chat in `#matrix:matrix.org` which room id is `!cURbafjkfsMDVwdRDQ:matrix.org`.

You will have to instantiate a MXKRoomViewController and attach a MXKRoomDataSource object to it. This object that will manage the room data. This gives the following code::

        // Create a data souce for managing data for the targeted room
        MXKRoomDataSource *roomDataSource = [[MXKRoomDataSource alloc] initWithRoomId:@"!cURbafjkfsMDVwdRDQ:matrix.org" andMatrixSession:mxSession];

        // Create the room view controller that will display it
        MXKRoomViewController *roomViewController = [[MXKRoomViewController alloc] init];
        [roomViewController displayRoom:roomDataSource];

Then, let your app present `roomViewController`. Your end user is now able to post messages or images to the room, he can navigate in the history, etc.

Use case #2: Display list of user's rooms
-----------------------------------------
The approach is similar to the previous use case. You need to create a data source and pass it to the view controller::

        // Create a data source for managing data
        MXKRecentListDataSource *recentListDataSource = [[MXKRecentListDataSource alloc] initWithMatrixSession:mxSession];

        // Create the view controller that will display it
        MXKRecentListViewController *recentListViewController = [[MXKRecentListViewController alloc] init];
        [recentListViewController displayList:recentListDataSource];


Customisation
=============

The kit has been designed so that developers can make customisations at different levels, which are:

viewcontroller

	The provided viewcontrollers can be subclassed in order to change their default behavior and the interactions with the end user.

cellview

	The developer can indicate to the datasource which view class it must use to render celldata. Thus, the display of items can be totally modified. Note that cellview classes must implement the MXKCellRendering protocol.

celldata

	The developer can provide another cellData class in order to compute data differently.

datasource

	This object gets the data from the Matrix SDK and serves it to the view controller via cellView and cellData objects. The developer can override the default one to have a different behaviour.
    
UIAppearance (Not yet available)

    Views in MatrixKit use the UIKit UIAppearance concept to allow easy skinning.
    

Customisation example
=====================

Use case #1: Change cells in the room chat
------------------------------------------
This use case shows how to make `cellView` customisation.

A room chat is basically a list of items where each item represents a message (or a set of messages if they are grouped by sender). In the code, these items are UITableViewCell inherited objects. If you are not happy with the default ones used by MXKRoomViewController and MXKRoomDataSource, you can request them to use a UITableViewCell class of your own as follow::

        // Init the room data source
        MXKRoomDataSource *roomDataSource = [[MXKRoomDataSource alloc] initWithRoomId:@"!cURbafjkfsMDVwdRDQ:matrix.org" andMatrixSession:mxSession];

        // `cellView` Customisation
        // Let the `MyOwnIncomingBubbleTableViewCell` class manage the display of message cells
        // This class must inherit from UITableViewCell and must conform the `MXKCellRendering` protocol
        [roomDataSource registerCellViewClass:MyOwnIncomingBubbleTableViewCell.class
                            forCellIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier];

        // Then finalise the room view controller
        MXKRoomViewController *roomViewController = [[MXKRoomViewController alloc] init];
        [roomViewController displayRoom:roomDataSource];
        
As you can notice, you can define different `cellView` classes for received and sent messages. 

Development
===========

If you want to help to improve MatrixKit by adding new viewcontrollers, new views, new cellviews or whatever, this git repository contains a sample Xcode project for demoing all reusable UI. 
Please hack on the `develop` branch and make git pull requests from it.

As its dependencies are based on CocoaPods, you will need to run `pod install` before opening MatrixKit.xcworkspace.


