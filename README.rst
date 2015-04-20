MatrixKit
=========

While `MatrixSDK 
<https://github.com/matrix-org/matrix-ios-sdk>`_ provides an Objective-C API to use the Matrix Client-Server API, MatrixKit provides, at an higher level, reusable and easy-customisable UI built at the top of the SDK.

Basicallly, MatrixKit is a set of viewcontrollers and views. An app developer can pick up UI components from this set and insert them into their application storyboard or code. The end application plays the role of director between them.

Each of the provided UI components has been designed to run standalone. There is no depency between them.

The currently available viewcontrollers are:

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

Here are two samples for displaying messages of a room.

The left one is the stock room viewcontroller. This is the one used by `Console 
<https://itunes.apple.com/gb/app/matrix-console/id970074271?mt=8>`_ (https://github.com/matrix-org/matrix-ios-console).

The right one is an override of `JSQMessagesViewController 
<https://github.com/jessesquires/JSQMessagesViewController>`_. The display is fully managed by  JSQMessagesViewController but the implemantation uses data computed by MatrixKit components: MXKRoomDataSource & MXKRoomBubbleCellData. See the next session for definition of datasource and celldata. 

.. image:: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKRoomViewController.jpeg
    :width: 240px
    :align: left

.. image:: https://raw.githubusercontent.com/matrix-org/matrix-ios-kit/develop/Screenshots/MXKJSQMessagesViewController.jpeg
    :width: 240px
    :align: right


Overview
========
All viewcontrollers in MatrixKit displaying a list of items share the same ecosystem based on 4 components:

viewcontroller

  	The viewcontroller is responsible for managing the display and the user actions.

datasource

 	It provides the viewcontroller with items (cellview objects) to display. More accurately, the datasource gets data(mainly Matrix events) from the Matrix SDK. It asks celldata objects to process the data into human readable text and store it. Then, when the viewcontroller asks for a cellview, it renders the corresponding celldata into a cellview that it returns.
    
 	For convenience, datasources provided in MatrixKit implement UITableViewDataSource and UICollectionViewDataSource protocols so that UITableView and UICollectionView datasources can be directly plugged to them.

celldata

     It contains data the cellview must display. There is one celldata object per item in the list. This is also a sort of cache to avoid to compute displayed data everytime.
     
cellview

     This is an abstract object. It is often a UITableViewCellView or a UICollectionViewCell but can be any UIView. This is the view for an item displayed by the viewcontroller.


Customisation
=============

The kit has been designed so that developers can make customisations at different levels, which are:

UIAppearance

    Views in  MatrixKit use the UIKit UIAppearance concept to allow easy skinning (Not yet available).
	
viewcontroller

	The provided viewcontrollers can be subclassed in order to change their default behavior.
	
cellview

	The developer can indicate to the datasource which view class it must use to render celldata. Thus, the display of items can be totally modified. Note that cellview classes must implement the MXKCellRendering protocol.
	
celldata

	The developer can provide another cellData class in order to compute data differently.

datasource

	This object gets the data from the Matrix SDK and serves it to the view controller via cellView and cellData objects. The developer can override the default one to have a different behaviour.
    

Customisation example
=====================

TODO.


Use it in your app 
==================

You can embed MatrixKit to your application project with CocoaPods. The pod for the last MatrixKit release is::

    pod 'MatrixKit'


Development
===========

If you want to help to improve MatrixKit by adding new viewcontrollers, new views, new cellviews or whatever, this git repository contains a sample Xcode project for demoing all reusable UI. 
Please hack code on the `develop` branch and make git pull requests from it.

As its dependencies are based on CocoaPods, you will need to run `pod install` before opening MatrixKit.xcworkspace.


