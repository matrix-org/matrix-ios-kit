MatrixKit
=========

MatrixKit provides reusable and easy-customisable UI built at the top of `MatrixSDK 
<https://github.com/matrix-org/matrix-ios-sdk>`_.

Basicallly, MatrixKit is a set of viewcontrollers and views the developer can pick up from and insert into his application storyboard or code.
Each of these provided UI components has been designed to run standalone. The application plays the role of director between them.

The currently available viewcontrollers are::

	- MXKRoomViewController: it shows messages of a room and allows user to chat
	- MXKRecentListViewController: it displays the rooms of the user ordered by their last message

Coming soon::

	- MXKRoomMemberListViewController: a page showing the list of members of a room
	- MXKPublicRoomList: the list of public rooms
	- ...


Overview
========
All viewcontrollers that displays a list of items share the same ecosystem based on 4 components:

viewcontroller
  	The viewcontroller is responsible for managing the display and the user actions.

datasource
 	It provides the viewcontroller with items (cellview objects) to display. More accurately, the datasource gets data(mainly Matrix events) from the Matrix SDK. It asks celldata objects to process the data and store it. Then, when the viewcontroller asks for a cellview, it renders the corresponding celldata into a cellview that it returns.
 	For convenience, the provided datasources implement UITableViewDataSource and UICollectionViewDataSource protocols so that UITableView and UICollectionView datasources can be directly plugged to them.

celldata
     It contains data the cellview must display. There is one celldata object per item in the list. This is also a sort of cache to avoid to compute data everytime.
     
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

