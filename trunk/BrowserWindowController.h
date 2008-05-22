//
//  BrowserWindowController.h
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  This is the controller for the main Terrabrowser window which 
//  shows the Terraserver map.
//
//  ********
//  Disclaimer: Terrabrowser was one of the first Cocoa programs I wrote and
//  as such, it is in no way representative of my current coding style! ;-) 
//  Many things are done incorrectly in this code base but I have not taken the
//  time to revise them for the open source release. There are also many compile
//  time warnings which should be corrected as some of them hint at serious problems.
//  If you work for a company looking to hire me, don't look too critically at this old code!
//  Similarly, if you're trying to learn Cocoa / Objective-C, keep this in mind.
//  ********

//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "MapSourceProtocol.h"

@class Waypoint;
@class Location;


@interface BrowserWindowController : NSWindowController {
	id <MapSourceProtocol> mapSource;		// currently the terraserver model
	
	IBOutlet id appController;

	NSToolbar * theToolbar;
	
	int downloadMode;  // normal = 0, or download region = 1
	
	Waypoint * waypointToGoto;

	IBOutlet id regText;
	
	// for downloading to a file
	IBOutlet id downloadWidthField;
	IBOutlet id downloadHeightField;
	IBOutlet id downloadProgress;
	IBOutlet id downloadWindow;
	IBOutlet id downloadQualitySlider;
	
	// for adding bookmarks
	IBOutlet id bookmarkNameField;
	int bookmarkType;
	id docToAddWptTo;
	
	// for contextual menus
	IBOutlet id mapContextualMenu;
	IBOutlet id openfilesMenuOutlet;
	Location * mouseClickLocation;
	
	IBOutlet id sizeStatus;
	
	IBOutlet id navigationView;
	
	IBOutlet id zoomSlider;
	IBOutlet id zoomView;
	
	//position fields for the toolbar (lots of them!) 
	
	IBOutlet id formattedLatField;
	IBOutlet id formattedLatView;

	IBOutlet id formattedLonField;
	IBOutlet id formattedLonView;
	
	IBOutlet id northingField;
	IBOutlet id northingView;
	
	IBOutlet id eastingField;
	IBOutlet id eastingView;
	
	IBOutlet id zoneNumberView;
	IBOutlet id zoneNumberField;
	
	// end of position fields for toolbar
	
	IBOutlet id typePopup;
	IBOutlet id typeView;
	
	IBOutlet id mapView;
	
	IBOutlet id browseOfflineCheck;
	
	IBOutlet id infoWindow;
	IBOutlet id infoWindowMenuItem;
	IBOutlet id infoWindowField;
	
	IBOutlet id bookmarkSheet;
	
	NSTimer * infoTimer;
}


- (IBAction)toggleInfoWindow:(id)sender;
- (void)startInfoWindowTimer:(BOOL)b;
- (void)updateInfoWindow;

- (IBAction)go:(id)sender;
- (IBAction)downloadRegion:(id)sender;
	
- (void)gotoWaypoint:(Waypoint*)waypoint;
- (IBAction)gotoBuiltInBookmark:(id)sender;

- (IBAction)showBookmarkSheet:(id)sender;
- (IBAction)closeBookmarkSheet:(id)sender;

- (IBAction)print:(id)sender;
- (IBAction)abort:(id)sender;

- (IBAction)moveDirection:(id)sender;

- (IBAction)zoomOut:(id)sender;
- (IBAction)zoomIn:(id)sender;

- (IBAction)sendCurrentLocationAvantGo:(id)sender;

// for contextual map menu.
- (IBAction)zoomOutOnMouseLocation:(id)sender;
- (IBAction)zoomInOnMouseLocation:(id)sender;
- (IBAction)centerOnMouseLocation:(id)sender;
- (void)setPositionToMouseLocation;
- (void)fillPopupFileList;

- (IBAction)addWaypointAtMouseLocationToDocument:(id)sender;
- (IBAction)addBookmarkAtMouseLocation:(id)sender;
- (IBAction)addBookmark:(id)sender;


- (IBAction)updatePositionWithFormattedField:(id)sender;
- (IBAction)updatePositionWithDegrees:(id)sender;
- (IBAction)updatePositionWithDMS:(id)sender;
- (IBAction)updatePositionWithDM:(id)sender;
- (IBAction)updatePositionWithUTM:(id)sender;
	
- (IBAction)setBrowseOffline:(id)sender;

- (Location*)currentMasterLocation;

- (IBAction)sendUpdatePrefsNotification:(id)sender;


// AppleScript

- (id)handleReloadCommand:(NSScriptCommand *)command;


@end
