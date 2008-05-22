//
//  WaypointDocument.h
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  Controls a single waypoint window.  Will be shared with GPS Connect in the future.
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


@class GPSFileParser;
@class Waypoint;
@class XMLElement;

@interface WaypointDocument : NSDocument {

	BOOL isBookmarkDocument;		// a special case, only one per running app.
	

	NSArray * icons;	
	NSToolbar * theToolbar;
	
	IBOutlet id tabView;
	
	IBOutlet id iconMenu;
	
	// toolbar outlets
	IBOutlet id findView;
	IBOutlet id findField;
	
	// drawer
	IBOutlet id drawer;
	IBOutlet id waypointDetailView;
	IBOutlet id trackDetailView;
	IBOutlet id routeDetailView;
	IBOutlet id fileDetailView;
	
	IBOutlet id urlField;
	
	// binding
	IBOutlet id waypointArrayController;
	IBOutlet id trackArrayController;
	IBOutlet id routeArrayController;
	
	IBOutlet id waypointTableView;
	IBOutlet id trackTableView;
	IBOutlet id routeTableView;
	IBOutlet id numWaypointsField;
	

	// formatting
	IBOutlet id myLatLonFormatter;
	
	IBOutlet id tableWaypointLat;
	IBOutlet id tableWaypointLon;
	IBOutlet id tableWaypointEle;
		
	
	// For XML Parsing.  May be moved to a different file at a later date
	/////////////////////////
	NSXMLParser * XMLParser;
	Waypoint * wptTemp;
	NSMutableString * nameTemp;
	NSMutableString * currentStringBuffer;
	BOOL containsUnsupportedElements;
	BOOL insideWpt;
	BOOL insideTrkpt;
	BOOL insideRtept;
	
	BOOL insideRte;
	BOOL insideTrk;
	BOOL insideTrkSeg;
	
	XMLElement * track;
	XMLElement * trackSeg;
	Waypoint * trkpt;
	
	XMLElement * route;
	Waypoint * rtept;
	
	NSString * gpxVersion;
	///////////////////////
	// end of XML parsing variables
	
	
	// File data members
	NSString * stringRep;		// string representation of the file
	NSData * dataRep;

	// master list of waypoints, tracks, etc. for this file
	XMLElement * waypointList;
	XMLElement * trackList;
	XMLElement * routeList;
	
	// optional GPX specific elements
	NSString * creatorName;				// <author>
	NSString * creatorEmail;			// <email>
	NSString * keywords;				// <keywords>
	NSString * gpxCreatorProgram;		// <creator>
	NSString * gpxDescription;			// <desc>
	NSString * gpxURL;					// <url>
	NSString * gpxURLName;				// <urlname>
	
	NSMutableDictionary * otherElements;		// assorted other gpx elements
}


- (NSWindow *)window;
- (void)initializeToolbar;


- (BOOL)isBookmarkDocument;
- (void)setIsBookmarkDocument:(BOOL)b;


- (IBAction)findWaypoint:(id)sender;
- (IBAction)deleteItem:(id)sender;
- (IBAction)addItem:(id)sender;

- (void)addPassedWaypoint:(Waypoint*)wpt;

- (Waypoint*)waypointNamed:(NSString*)s;

- (IBAction)gotoCurrentlySelectedWaypoint:(id)sender;
- (IBAction)sendCurrentlySelectedWaypointToCustomURL:(id)sener;
- (IBAction)sendCurrentlySelectedWaypointToMapquest:(id)sender;
- (IBAction)sendCurrentlySelectedWaypointToGoogleMaps:(id)sender;

- (IBAction)sendRedrawNotification:(id)sender;

- (IBAction)gotoFilesURL:(id)sender;

- (IBAction)toggleDrawer:(id)sender;

- (void)setWaypointList:(XMLElement*)newList;
- (void)setTrackList:(XMLElement*)newList;

- (NSArray*)waypointArray;
- (NSArray*)tracks;
- (NSArray*)routes;
	

- (IBAction)printDocument:(id)sender;

- (IBAction)checkAllTracks:(id)sender;
- (IBAction)uncheckAllTracks:(id)sender;
- (IBAction)checkAllRoutes:(id)sender;
- (IBAction)uncheckAllRoutes:(id)sender;


- (IBAction)saveDocument:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;


@end
