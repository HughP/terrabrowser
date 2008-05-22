//
//  WaypointDocument.m
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
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

#import "WaypointDocument.h"
#import "Waypoint.h"
#import "Ellipsoid.h"
#import "AppController.h"
#import "LatLon.h"
#import "GPSFileParser.h"

#import "LatLonFormatter.h"

typedef enum {
	WPT_TAB		= 0,
	TRK_TAB		= 1,
	RTE_TAB		= 2,
	FILE_TAB	= 3
} TabType;


@interface WaypointDocument ()

- (TabType)selectedTab;
- (NSArray *)selectedWaypoints;
- (NSArray *)selectedTracks;
- (NSArray *)selectedRoutes;

- (Waypoint *)selectedTrackWaypoint;
- (Waypoint *)selectedRouteWaypoint;

- (void)checkOrUncheck:(XMLElement *)element check:(BOOL)toCheck forTableView:(id)tableView;
- (NSArrayController*)selectedArrayController;

- (void)tellMapToRefresh;

@end


@implementation WaypointDocument

- (id)init {
	
    if (self = [super init]) {
	
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
				
		dataRep = nil;
		XMLParser = nil;
		
		otherElements = [[NSMutableDictionary alloc] init];
		
		waypointList = [[XMLElement alloc] init];
		trackList = [[XMLElement alloc] init];
		routeList = [[XMLElement alloc] init];
		
		[[tableWaypointLat dataCell] setFormatter:[[[LatLonFormatter alloc] init] autorelease]];
		
		//icons = [[NSArray arrayWithObjects: @"blah", nil ] retain];
		//icons = [[NSArray arrayWithObjects: [NSImage imageNamed:@"icon00000.pict"], [NSImage imageNamed:@"icon00001.pict"], nil ] retain];

	} else {  //an error occured
		[self release];
		return nil;
	}
	
    return self;
}


- (void)awakeFromNib {
	
	// set up the default tab view connections so the search field will work.
	[self tabView:tabView didSelectTabViewItem:[tabView selectedTabViewItem]];
	
	
	// Set up the menu of waypoint icons.
	////////////////////
			
	NSArray * iconNames = [[Waypoint iconNames] sortedArrayUsingSelector:
		@selector(caseInsensitiveCompare:)];
	NSEnumerator * enumerator = [iconNames objectEnumerator];
	NSMenuItem * anItem;
	id element;
	while (element = [enumerator nextObject]) {
		anItem = [[NSMenuItem alloc] init];
		[anItem setTitle:element];
//		[anItem setTag:element];
		[anItem setImage: [Waypoint iconForSymbolName:element]];
		[iconMenu addItem: anItem];
		[anItem release];
		anItem = nil;
	}

}

- (void)showWindows {
	
	[super showWindows];
	
	[self initializeToolbar];
	
	// expand the drawer by default (if the user wants that behavior)
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WaypointShowDetailDrawerOnOpen"]) {
		[self toggleDrawer:self];	
	}
	
	
	// send a notification so the map will update and display the newly loaded labels.
	[self tellMapToRefresh];
	
	//set the url to show when the user clicks on the URL field.
	//	[urlField setURLWithString:gpxURL];
	

}

- (NSWindow *)window {
	
    NSArray *controllers = [self windowControllers];
	
	if (nil == controllers) {
		return nil;
	}
		
    return [[controllers objectAtIndex:0] window];
}

- (void)setWaypointList:(XMLElement*)newList {
	if (newList != waypointList) {
		[waypointList release];		
		waypointList = [newList retain];
	}
}

- (void)setTrackList:(XMLElement*)newList {
	if (newList != trackList) {
		[trackList release];
		trackList = [newList retain];
	}	
}


- (NSArray *)waypointArray {
	return (NSArray*) [waypointList list];
}

- (NSArray*)tracks {
	return (NSArray*) [trackList list];
}

- (NSArray*)routes {
	return (NSArray*) [routeList list];
}

- (int)test {	
	return 5;
}


#pragma mark -
#pragma mark Toolbar methods


- (void)initializeToolbar {

	//setup and add the toolbar
	theToolbar = [[NSToolbar alloc] initWithIdentifier:@"WaypointDocumentToolbar"];
	[theToolbar setDelegate:self];
	[theToolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	[theToolbar setAllowsUserCustomization:YES];
	[theToolbar setAutosavesConfiguration:YES];
	[theToolbar setSizeMode:NSToolbarSizeModeSmall];
	
	[[self window] setToolbar:theToolbar];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
		   itemForItemIdentifier:(NSString*)itemIdentifier 
			willBeInsertedIntoToolbar:(BOOL)flag  {
	
	NSToolbarItem * item;
	item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	
	if ([itemIdentifier isEqualToString:@"InfoButton"]) {
		[item setLabel:@"Info"];
		[item setPaletteLabel:@"Info"];	
		[item setToolTip:@"Information"];
		[item setImage:[NSImage imageNamed:@"Inspector"]];
		[item setAction:@selector(toggleDrawer:)];
	} else if ([itemIdentifier isEqualToString:@"FindView"]) {
		[item setLabel:@"Find"];
		[item setPaletteLabel:@"Find"];		
		[item setView:findView];
		[item setMinSize:([findView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"GoButton"]) {
		[item setLabel:@"Go"];
		[item setPaletteLabel:@"Go"];		
		[item setImage:[NSImage imageNamed:@"Evaluate"]];
		[item setAction:@selector(gotoCurrentlySelectedWaypoint:)];
	} else if ([itemIdentifier isEqualToString:@"AddButton"]) {
		[item setLabel:@"Add"];
		[item setPaletteLabel:@"Add"];		
		[item setImage:[NSImage imageNamed:@"plus"]];
		[item setAction:@selector(addItem:)];
			
	} else if ([itemIdentifier isEqualToString:@"DeleteButton"]) {
		[item setLabel:@"Delete"];
		[item setPaletteLabel:@"Delete"];		
		[item setImage:[NSImage imageNamed:@"minus"]];
		[item setAction:@selector(deleteItem:)];
	}
	
	[item autorelease];	
	
	return item;
}

//returns an array of all allowable toolbar item identifiers
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSArray * array = [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		@"AddButton",
		@"DeleteButton",
		@"FindView",
		@"InfoButton",
		@"GoButton",
		nil];
	
	return array;
}

//returns an array representing the default set of toolbar identifiers.
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	NSArray * array = [NSArray arrayWithObjects:
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier, 
		@"AddButton",
		@"DeleteButton",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"GoButton",
		@"FindView", @"InfoButton",
		 nil];
	
	return array;
}


#pragma mark -
#pragma mark Printing methods

//- (void)printShowingPrintPanel:(BOOL)flag {
	/*
	 NSRect r;
	r.width = 500;
	r.height = 700;
	
	NSView * printView = [[NSView alloc] initWithFrame:r];
	
	
	
	NSPrintOperation * printOp = [NSPrintOperation printOperationWithView:printView];
	[printOp runOperation];
	 */
//}

#pragma mark -
#pragma mark File methods


// first called if they want to save the document.
- (IBAction)saveDocument:(id)sender {
	
	if ((! [gpxCreatorProgram hasPrefix:@"Terrabrowser"]) ||
		([gpxVersion isGreaterThan: [self gpxVersionSupported]])) {
			int result = NSRunCriticalAlertPanel(@"GPX Compatibility Warning", 
											 [NSString stringWithFormat:@"Either this GPX file was not created by Terrabrowser, or it uses a newer version of the GPX standard than Terrabrowser uses.  Saving over this file may result in lost data.  To be safe, you should either use Save As, or make a backup copy of the original file first to make sure it works correctly."],
											 @"Save As", @"Save", @"Don't Save", nil);
		

		switch (result) {
			case -1:	//don't save
				return;
				break;
			case 0:		//save
				[super saveDocument:sender];
				return;
			case 1:		//save as
				[super saveDocumentAs:sender];
				return;
		}
	}
	
	[super saveDocument:sender];
	
	// If we have saved the document, then the GPX version is now the same
	// as our version.  
	if (gpxVersion != [self gpxVersionSupported]) {
		[gpxVersion release];
		gpxVersion = [[self gpxVersionSupported] retain];		
	}
}


- (NSData *)dataRepresentationOfType:(NSString *)aType {
    // Insert code here to write your document from the given data. 
	// You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

//	NSLog(@"In dataRepresentationOfType");
	
	NSString * gpx = [self gpxString];
	NSData * d = [gpx dataUsingEncoding:NSISOLatin1StringEncoding];
	
	return d;
	//returning nil will give the user an error message
}



- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType {
    // Insert code here to read your document from the given data. 
	// You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
	
	[dataRep release];
	dataRep = [data retain];
		
	// for now, just assume it's in GPX format.  Later, add other formats.
	BOOL success = [self parseAsGPXFile];

	
	if (! success) {
		NSLog(@"problem parsing XML file");
	}
    return success;
}



#pragma mark -
#pragma mark Action methods


// Prints the currently selected table view in the waypoint document.
- (IBAction)printDocument:(id)sender {
	
	id view = nil;
	switch ((int)[self selectedTab]) {
		case WPT_TAB:		// waypoints
			view = waypointTableView;
			break;
		case TRK_TAB:		// tracklogs
			view = trackTableView;
			break;
		case RTE_TAB:		// routes
			view = routeTableView;
			break;
	}
	
	if (nil == view) return;
	
	[[NSPrintOperation printOperationWithView:view] runOperation];
}


- (IBAction)gotoFilesURL:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:gpxURL]];
}


- (IBAction)sendCurrentlySelectedWaypointToMapquest:(id)sender {
	NSArray * wpts = [self selectedWaypoints];
	
	if ([wpts count] <= 0) return;
	
	NSEnumerator * e = [wpts objectEnumerator];
	id obj;
	
	// open each of the waypoints in mapquest
	while (obj = [e nextObject]) {
		NSString * urlString = [NSString stringWithFormat:@"http://www.mapquest.com/maps/map.adp?latlongtype=decimal&latitude=%f&longitude=%f", [obj doubleLatitude], [obj doubleLongitude]];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];		
	}
}

- (IBAction)sendCurrentlySelectedWaypointToGoogleMaps:(id)sender {
	NSArray * wpts = [self selectedWaypoints];
	
	if ([wpts count] <= 0) return;
	
	NSEnumerator * e = [wpts objectEnumerator];
	id obj;

	
	// open each of the waypoints in google maps
	while (obj = [e nextObject]) {
		NSString * urlString = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%f%%2c%f", [obj doubleLatitude], [obj doubleLongitude]];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
	}
}


// Opens a web page with the custom URL the user defined in the preferences
// filling in the selected latitude and longitude.
- (IBAction)sendCurrentlySelectedWaypointToCustomURL:(id)sender {
	NSArray * wpts = [self selectedWaypoints];
	
	if ([wpts count] <= 0) return;
	
	NSEnumerator * e = [wpts objectEnumerator];
	id obj;
	
	// open each of the waypoints in mapquest
	while (obj = [e nextObject]) {
		// this URL 
		NSString * customURL = [[NSUserDefaults standardUserDefaults] stringForKey:@"BrowserCustomURL"];
		if ([customURL length] <= 15) return;
		
		NSString * urlString = [NSString stringWithFormat:customURL, [obj doubleLatitude], [obj doubleLongitude]];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];		
	}
}



// goto the waypoint currently selected in the table view
// if a tracklog or route is present, it goes to the first waypoint
// in that tracklog or route.
- (IBAction)gotoCurrentlySelectedWaypoint:(id)sender {
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];

	id obj = nil;
	
	switch ((int)[self selectedTab]) {
		case WPT_TAB:		// waypoints
			obj = [[self selectedWaypoints] objectAtIndex:0];
			break;
		case TRK_TAB:		// tracklogs
			obj = [self selectedTrackWaypoint];
			break;
		case RTE_TAB:		// routes
			obj = [self selectedRouteWaypoint];
			break;
	}
	
	[nc postNotificationName:@"MOOGotoWaypoint" object:obj];
}

- (IBAction)sendRedrawNotification:(id)sender {
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOODoRedrawMapView" object:nil];	
}


- (IBAction)findWaypoint:(id)sender {
//	[waypointList filterWithSearchString:[findField stringValue]];
//	[self updateWindowDisplay];
}

- (IBAction)toggleDrawer:(id)sender {
	NSSize size;
	
	
	//NSLog(@"width = %f, height = %f", size.width, size.height );
	
	size = [[drawer contentView] frame].size;
	[drawer setMinContentSize: size];
	
	[drawer toggle:self];
}


- (IBAction)deleteItem:(id)sender {
	[[self selectedArrayController] remove:sender];
}

- (IBAction)addItem:(id)sender {
	[[self selectedArrayController] add:sender];
}


- (IBAction)checkAllTracks:(id)sender {
	[self checkOrUncheck:trackList check:YES forTableView:trackTableView];
}

- (IBAction)uncheckAllTracks:(id)sender {
	[self checkOrUncheck:trackList check:NO forTableView:trackTableView];
}

- (IBAction)checkAllRoutes:(id)sender {
	[self checkOrUncheck:routeList check:YES forTableView:routeTableView];
}

- (IBAction)uncheckAllRoutes:(id)sender {
	[self checkOrUncheck:routeList check:NO forTableView:routeTableView];
}

#pragma mark -
#pragma mark Clipboard methods

// copies selected waypoints, tracks, or routes to the clipboard
- (IBAction)copy:(id)sender {

	NSPasteboard * pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObjects:@"MOOArrayOfWaypointsType", NSStringPboardType, nil]
			   owner:self];

	
	NSMutableString * stringToPaste = [NSMutableString stringWithCapacity:2];
	NSEnumerator * e = nil;
	id obj;
	
	switch ((int)[self selectedTab]) {
		case WPT_TAB:
			[pb setData:[NSArchiver archivedDataWithRootObject:[self selectedWaypoints]]
				forType:@"MOOArrayOfWaypointsType"];

			e = [[self selectedWaypoints] objectEnumerator];
			break;
		case TRK_TAB:
			e = [[self selectedTracks] objectEnumerator];
			break;
		case RTE_TAB:
			e = [[self selectedRoutes] objectEnumerator];
			break;
	}
	
	// concatenate all of the strings
	// for multiple selections
	while (obj = [e nextObject]) {
		[stringToPaste appendString:[obj gpxString]];
	}
	
	[pb setString:stringToPaste
		  forType:NSStringPboardType];
	 
}


- (IBAction)paste:(id)sender {
	NSPasteboard * pb = [NSPasteboard generalPasteboard];
	NSString * type = [pb availableTypeFromArray:[NSArray arrayWithObject:@"MOOArrayOfWaypointsType"]];
	
	if (!type) return;
	NSData * data;
	NSArray * array;
	NSEnumerator * e;
	id obj;
		
	switch ((int)[self selectedTab]) {
		case WPT_TAB:
			data = [pb dataForType:@"MOOArrayOfWaypointsType"];
			array = (NSArray*)[NSUnarchiver unarchiveObjectWithData:data];
			
			e = [array objectEnumerator];
			while (obj = [e nextObject]) {
				[self addPassedWaypoint:(Waypoint*)obj];
			}
			
			break;
		case TRK_TAB:
			break;
		case RTE_TAB:
			break;
	}
}


#pragma mark -
#pragma mark Other methods

// returns the waypoint with the passed name, or nil if none is found
- (Waypoint*)waypointNamed:(NSString*)s {
	NSEnumerator * e = [[self waypointArray] objectEnumerator];
	id obj;
	
	while (obj = [e nextObject]) {
		if ([[obj name] isEqualToString:s]) {
			return (Waypoint*)obj;
		}
	}
	
	return nil;
}

- (BOOL)isBookmarkDocument { return isBookmarkDocument; }
- (void)setIsBookmarkDocument:(BOOL)b { isBookmarkDocument = b; }


- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports 
	// multiple NSWindowControllers, you should remove this method 
	// and override -makeWindowControllers instead.
    return @"WaypointDocument";
}


/*
 - (void)makeWindowControllers {
	// create window controller
	windowController = [[NSWindowController alloc] initWithWindowNibName:@"WaypointDocument"];
    [self addWindowController:windowController];
	
	// add to document list
}
*/

- (void)windowControllerDidLoadNib:(NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
}


- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
	
	
	return [super validateMenuItem:anItem];
}



// returns the currently selected waypoints
- (NSArray *)selectedWaypoints {
	return [waypointArrayController selectedObjects];
}

// returns the currently selected track logs
- (NSArray *)selectedTracks {
	return [trackArrayController selectedObjects];
}

- (Waypoint *)selectedTrackWaypoint {
	return [[[self selectedTracks] objectAtIndex:0] objectAtIndex:0];
}


// returns the currently selected routes
- (NSArray *)selectedRoutes {
	return (NSArray *) [routeArrayController selectedObjects];
}

- (Waypoint *)selectedRouteWaypoint {
	return [[[[self selectedRoutes] objectAtIndex:0] list] objectAtIndex:0];
}

// which tab is selected?
- (TabType)selectedTab {
	return (TabType)((int)[[[tabView selectedTabViewItem] identifier] intValue]);
}

// returns the array controller associated with the currently selected tab
// or nil if not applicable.
- (NSArrayController*)selectedArrayController {

 	switch ((int)[self selectedTab]) {
		case WPT_TAB:		// waypoints
			return waypointArrayController;
			break;
		case TRK_TAB:		// tracklogs
			return trackArrayController;
			break;
		case RTE_TAB:		// routes
			return routeArrayController;
			break;
	}
	
	return nil;
}


- (void)addPassedWaypoint:(Waypoint*)wpt {
	[waypointArrayController addObject: wpt];
}


- (void)checkOrUncheck:(XMLElement *)element check:(BOOL)toCheck forTableView:(id)tableView {
	NSEnumerator * enumerator = [element objectEnumerator];
	id obj;
	while (obj = [enumerator nextObject]) { [obj setIncludeInList:toCheck]; }
	
	[tableView reloadData];	
	[self sendRedrawNotification:self];
}

- (void)tellMapToRefresh {
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOODoRefreshMapView" object:nil];		
}


#pragma mark -
#pragma mark Delegate methods



//gets called when the text in the find box changes..  Note, this may be
//called by other things to..  So *******WATCH OUT****..  probably would be
//better to have a custom class of NSTextField to do this.
//- (void)controlTextDidChange:(NSNotification *)aNotification {
//	if ([aNotification object] == findField) {
//		[self findWaypoint:self];
//	}
//}


// if it's the bookmark document, then we don't want the user to close it by accident.
- (BOOL)windowShouldClose:(id)sender {
	if (isBookmarkDocument) {
		[[self window] orderOut:sender];
		return NO;
	}

	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification {
	if (isBookmarkDocument) {
		// save changes
		[self saveDocument:self];
	}
	
	//send a notification so the map will update and remove the waypoints, etc. from this document.
	[self tellMapToRefresh];
}


// called when the user selects a different tab from the tab view.
// this sets the detail view in the drawer appropriately
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	id delegate = waypointArrayController;
	BOOL enableFind = YES;
	
	switch ((int)[self selectedTab]) {
		case WPT_TAB:
			[drawer setContentView: waypointDetailView];
			delegate = waypointArrayController;
			enableFind = YES;			
			break;
		case TRK_TAB:
			[drawer setContentView: trackDetailView];
			delegate = trackArrayController;
			enableFind = YES;			
			break;
		case RTE_TAB:
			[drawer setContentView: routeDetailView];
			delegate = routeArrayController;
			enableFind = YES;			
			break;
		case FILE_TAB:
			[drawer setContentView: fileDetailView];
			delegate = nil;
			enableFind = NO;			
			break;
	}
	
	// update which array controller the find view 
	// uses for filtering the array.
	[findField setDelegate:delegate];
	[findField setTarget:delegate];
	[findField setEnabled:enableFind];
	
	// update the add and delete buttons in the toolbar so they'll 
	// add or delete from the correct array controller.
	NSEnumerator * e = [[theToolbar items] objectEnumerator];
	id item;
	while (item = [e nextObject]) {
		if (([[item label] isEqualTo:@"Add"]) || ([[item label] isEqualTo:@"Delete"])) {
			[item setEnabled: enableFind];
		}
 	}
}

- (void)dealloc {
	[theToolbar release];
	[waypointList release];
	[trackList release];
	[stringRep release];
	[dataRep release];
	[creatorName release];
	[creatorEmail release];	
	
	/*
	[wptTemp release];
	[nameTemp release];
	[currentStringBuffer release];
	[track release];
	[trackSeg release];
	[trkpt release];
	 */
		
	[XMLParser release];
	[otherElements release];
	[icons release];
	
	[super dealloc];
}

@end
