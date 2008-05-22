//
//  BrowserWindowController.m
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

#import "BrowserWindowController.h"
#import "TerraserverModel.h"
#import "Location.h"
#import "Waypoint.h"
#import "Ellipsoid.h"
#import "Constants.h"
#import "MapView.h"
#import "LatLon.h"
#import "LatLonFormatter.h"

typedef enum {
	BookmarkMouseLocation		= 0,
	BookmarkBrowserLoction		= 1,
	AddWaypointAtMouseLocation  = 2
} BookmarkModeType;

static const int DOWNLOAD_NORMAL = 0;
static const int DOWNLOAD_REGION = 1;

@interface BrowserWindowController ()

- (void)updatePositionWithWaypoint:(Waypoint*)wpt;
- (void)createNewMapSourceIfNeeded;
- (void)adjustMaximumZoomLevel;
- (int)selectedType;
- (void)bookmarkSheetDone;

@end



@implementation BrowserWindowController

#pragma mark -
#pragma mark Init methods


- (void)awakeFromNib {	
	
	downloadMode = DOWNLOAD_NORMAL;
	
	[[self window] setFrameUsingName: @"BrowserWindowFrame"];
	
	//setup and add the toolbar
	theToolbar = [[NSToolbar alloc] initWithIdentifier:@"BrowserToolbar"];
	[theToolbar setDelegate:self];
	[theToolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	[theToolbar setAllowsUserCustomization:YES];
	[theToolbar setAutosavesConfiguration:YES];
	
	[[self window] setToolbar:theToolbar];
	
	//restore some default values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	Waypoint* wpt;
	
	if ([defaults boolForKey:@"PrefsValid"]) {
		
		[browseOfflineCheck setState:[defaults boolForKey:@"BrowseOffline"]];
		
		wpt = [[Waypoint waypointWithDoubleLatitude:[defaults floatForKey:@"BrowserLatitude"]
									doubleLongitude:[defaults floatForKey:@"BrowserLongitude"]] retain];
		
		[self updatePositionWithWaypoint: wpt];
		[wpt release];
		
		[zoomSlider setIntValue:[defaults integerForKey:@"BrowserZoom"]];
		
		int tag = 0;
		if ([defaults integerForKey:@"MapTypeTag"] != nil) {
			tag = [defaults integerForKey:@"MapTypeTag"];
		}
		
		[typePopup selectItemAtIndex:[typePopup indexOfItemWithTag:tag]];
	} else {
		// prefs are not valid
		wpt = [[Waypoint waypointWithDoubleLatitude:32.22886
									doubleLongitude:-110.94859] retain];
		
		[self updatePositionWithWaypoint: wpt];
		[wpt release];
		
	}

	
	
	//Now, we'll add ourself as an observer for this notification
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	
	[nc  addObserver: self
			selector: @selector(reload)
				name: @"MOOReloadCurrentLocation"
			  object: nil];

	
	[self createNewMapSourceIfNeeded];
	[self adjustMaximumZoomLevel];		// so the slider doesn't go to far.
	
}


- (id)init {
	if (self = [super init]) {
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		
		[nc  addObserver: self
				selector: @selector(mapViewKeyDown:)
					name: @"MOOMapViewKeyDown"
				  object: nil];
		
		
		[nc  addObserver: self
				selector: @selector(updatePlaceAndDate:)
					name: @"MOOPlaceAndDateDownloaded"
				  object: nil];
		
		[nc  addObserver: self
				selector: @selector(gotoWaypointNotification:)
					name: @"MOOGotoWaypoint"
				  object: nil];
				
		[nc  addObserver: self
				selector: @selector(mapDownloadProgress:)
					name: @"MOOMapDownloadProgress"
				  object: nil];

		[nc  addObserver: self
				selector: @selector(mapDownloadFinished:)
					name: @"MOOMapDownloadFinished"
				  object: nil];
		
	}
	
	return self;
}

#pragma mark -
#pragma mark Toolbar methods


// sets the action, picture, and label for each toolbar item
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
		itemForItemIdentifier:(NSString*)itemIdentifier 
 willBeInsertedIntoToolbar:(BOOL)flag {
	
	NSToolbarItem * item;
	item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	
	if ([itemIdentifier isEqualToString:@"GoButton"]) {
		[item setLabel:@"Go"];
		[item setPaletteLabel:@"Go"];
		[item setToolTip:@"Fetch Images"];
		[item setAction:@selector(go:)];
		[item setImage:[NSImage imageNamed:@"Evaluate"]];
	} else if ([itemIdentifier isEqualToString:@"StopButton"]) {
		[item setLabel:@"Stop"];
		[item setPaletteLabel:@"Stop"];
		[item setAction:@selector(abort:)];
		[item setImage:[NSImage imageNamed:@"Stop"]];
	} else if ([itemIdentifier isEqualToString:@"ZoomView"]) {
		[item setLabel:@"Zoom"];
		[item setPaletteLabel:@"Zoom"];
		[item setAction:@selector(go:)];
		[item setView:zoomView];
		[item setMinSize:([zoomView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"TypeView"]) {
		[item setLabel:@"Type"];
		[item setPaletteLabel:@"Type"];		
		[item setAction:@selector(go:)];
		[item setView:typeView];
		[item setMinSize:([typeView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"FormattedLatView"]) {
		[item setLabel:@"Latitude"];
		[item setPaletteLabel:@"Latitude"];
		[item setView:formattedLatView];
		[item setMinSize:([formattedLatView frame].size)];				
	} else if ([itemIdentifier isEqualToString:@"FormattedLonView"]) {
		[item setLabel:@"Longitude"];
		[item setPaletteLabel:@"Longitude"];
		[item setView:formattedLonView];
		[item setMinSize:([formattedLonView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"EastingView"]) {
		[item setLabel:@"Easting"];
		[item setPaletteLabel:@"Easting"];		
		[item setView:eastingView];
		[item setMinSize:([eastingView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"NorthingView"]) {
		[item setLabel:@"Northing"];
		[item setPaletteLabel:@"Northing"];		
		[item setView:northingView];
		[item setMinSize:([northingView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"ZoneNumberView"]) {
		[item setLabel:@"Zone"];
		[item setPaletteLabel:@"Zone"];		
		[item setView:zoneNumberView];
		[item setMinSize:([zoneNumberView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"NavigationButtons"]) {
		[item setLabel:@"Navigate"];
		[item setPaletteLabel:@"Navigate"];	
		[item setToolTip:@"Navigation (tip: you can also use the keyboard arrows)"];
		[item setView:navigationView];
		[item setMinSize:([navigationView frame].size)];
	} else if ([itemIdentifier isEqualToString:@"InfoButton"]) {
		[item setLabel:@"Info"];
		[item setPaletteLabel:@"Info"];	
		[item setToolTip:@"Information"];
		[item setAction:@selector(toggleInfoWindow:)];
		[item setImage:[NSImage imageNamed:@"Inspector"]];
	} else if ([itemIdentifier isEqualToString:@"FindButton"]) {
		[item setLabel:@"Find"];
		[item setPaletteLabel:@"Find"];	
		[item setToolTip:@"Find"];
		[item setAction:@selector(findButtonPressed:)];
		[item setImage:[NSImage imageNamed:@"Find"]];
	} else if ([itemIdentifier isEqualToString:@"BookmarksButton"]) {
		[item setLabel:@"Bookmarks"];
		[item setPaletteLabel:@"Manage Bookmarks"];	
		[item setToolTip:@"Manage Bookmarks"];
		[item setAction:@selector(manageBookmarks:)];
		[item setImage:[NSImage imageNamed:@"Bookmarks"]];
	} else if ([itemIdentifier isEqualToString:@"OpenFile"]) {
		[item setLabel:@"Open"];
		[item setPaletteLabel:@"Open"];	
		[item setToolTip:@"Open"];
		[item setImage:[NSImage imageNamed:@"OpenIcon"]];
		[item setAction:@selector(openDocument:)];
	}
	
	
	// Set the minimum and maximum allowable values for the latitude and
	// longitude fields.
	LatLonFormatter * f = [formattedLatField formatter];
	[f setMinimum:-90.0];
	[f setMaximum:90.0];
	
	f = [formattedLonField formatter];
	[f setMinimum:-180.0];
	[f setMaximum:180.0];
	
	[item autorelease];	
	return item;
}


//returns an array of all allowable toolbar item identifiers
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSArray * array = [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		@"FormattedLonView",
		@"FormattedLatView",
		@"EastingView",
		@"NorthingView",
		@"ZoneNumberView",
		@"ZoomView",
		@"TypeView",
		@"GoButton",
		@"StopButton",
		@"FindButton",
		@"InfoButton",
		@"BookmarksButton",
		@"NavigationButtons", @"OpenFile", nil];
	
	return array;
}

//returns an array representing the default set of toolbar identifiers.
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	NSArray * array = [NSArray arrayWithObjects:
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier, 
		@"FormattedLatView",
		@"FormattedLonView",
		@"ZoomView",
		@"TypeView",
		@"GoButton", 
		@"StopButton",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"NavigationButtons", nil];
	
	return array;
}



#pragma mark -
#pragma mark Assorted methods




// download a region to a file but don't display it on the mapview.
- (IBAction)downloadRegion:(id)sender {
	downloadMode = DOWNLOAD_REGION;
	
	[self createNewMapSourceIfNeeded];
	
	Waypoint* wpt = waypointToGoto;
	
	NSSize size;
	size.height = [downloadHeightField intValue];
	size.width = [downloadWidthField intValue];
	
	[mapSource setSize: size
			  location: [wpt location]
				  zoom: [zoomSlider intValue]
			   andType: [self selectedType]];
	
	[mapSource startImageTransfer];  //actually load and display the waypoint..
}


// load image centered at the passed waypoint.
- (void)gotoWaypoint:(Waypoint*)wpt {
	downloadMode = DOWNLOAD_NORMAL;
	
//	NSLog(@"Loading the image");
	
	[self createNewMapSourceIfNeeded];
	
	if (nil == wpt) wpt = waypointToGoto;
	
	[mapSource setSize: [mapView mapSize]
			  location: [wpt location]
				  zoom: [zoomSlider intValue]
			   andType: [self selectedType]];
	
	[mapSource startImageTransfer];  //actually load and display the waypoint..
	
	[[self window] setTitle:@"loading..."];
	
//	[mapView didMoveOrResize];
}


- (IBAction)manageBookmarks:(id)sender {
	[appController manageBookmarks:self];
}

// Creates the mapSource object if it doesn't already exist.  
// also makes sure that it has the correct number of tiles in it 
// based on the current window size (creates a new model if it has to).
- (void)createNewMapSourceIfNeeded {

	BOOL resized = NO;
	if (nil != mapSource) {
		if ((([mapView mapSize].height) != ([mapSource mapSize].height)) || 
			(([mapView mapSize].width) != ([mapSource mapSize].width)) ){
			resized = YES;
		}
	}
	
	
	//at this point, mapSource should not be nil
	if ((nil == mapSource) || resized) {
		// we only have the TerraserverModel at this point, but in 
		// the future, we might have other image servers, scanned images,
		// etc.  
		
		// so this is hard coded for now.
		mapSource = [[[TerraserverModel alloc] 
			initWithSize: [mapView mapSize]
				location: [waypointToGoto location]
					zoom: [zoomSlider intValue]
				 andType: [self selectedType] ] retain];
	
		[mapView setMapSource:mapSource];
	}
	


		
	
}





// called after the user has edited one of the position fields in the toolbar.
// it should set this passed waypoint as the current position, and then update the
// other fields to match.
- (void)updatePositionWithWaypoint:(Waypoint*)wpt {
	NSAssert(wpt != nil, @"passed nil waypoint to updatePositionWithWaypoint");
	
	//set the waypoint to go to.
	waypointToGoto = [wpt retain];
	Location * loc = [wpt location];
	
	LatLon* lat = [wpt latitude];
	LatLon* lon = [wpt longitude];

	[formattedLatField setObjectValue: lat];
	[formattedLonField setObjectValue: lon];
		
	[eastingField setDoubleValue: [loc easting]];
	[northingField setDoubleValue: [loc northing]];
	[zoneNumberField setIntValue: [loc zoneNumber]];	
	
//	NSLog(@"latitude = %f", [[wpt latitude] doubleDegrees]);
//	NSLog(@"longitude = %f", [[wpt longitude] doubleDegrees]);
	
//	NSLog(@"easting = %f", [wpt easting]);
//	NSLog(@"northing = %f", [wpt northing]);
	
//	NSLog(@"zoneNum = %d", [wpt zoneNumber]);
	
}


- (void)startInfoWindowTimer:(BOOL)b {
	float rate = 0.1;  // 10 times per second.
	
//	NSLog(@"stopping info timer");
	
	//stop and destroy the timer if it exists
	if ([infoTimer isValid]) {
		[infoTimer invalidate]; //stop it
	}
	
	if (infoTimer != nil) {
		[infoTimer release];
		infoTimer = nil;
	}
	
	
	//create and start timer if b.
	if (b) {  
		NSLog(@"starting info timer");	
		if (!infoTimer) {  //then create it
			infoTimer = [[NSTimer scheduledTimerWithTimeInterval:rate
														  target:self
														selector:@selector(updateInfoWindow)
														userInfo:0
														 repeats:YES] retain];
		}	
	}
	
}


- (Location*)currentMasterLocation {
	return [mapSource location];
}

// the selected type from the type popup menu.
- (int)selectedType {	
	return [[typePopup selectedItem] tag];
}

// Different types of maps have different allowable maximum zoom levels.
// If the user switches from one which allows a closer zoom to another which doesn't,
// we should update their maximum zoom level to the new max.
- (void)adjustMaximumZoomLevel {
	[mapSource setMapType: [self selectedType]];
	
	int max = [mapSource maximumAllowableZoomLevel];
	
	int oldValue = [zoomSlider intValue];
	
	// It's the minimum value on the slider, even though we call it the maximum zoom
	// because it's fully zoomed in.
	[zoomSlider setMinValue: max];	
	int numTicks = [zoomSlider maxValue] - max + 1;	
	[zoomSlider setNumberOfTickMarks:numTicks];
	
	if (oldValue < max) {
		[zoomSlider setIntValue:max];
	}
	
	[zoomSlider setNeedsDisplay:YES];
}

//update the display in the info window
- (void)updateInfoWindow {
	// Note, it seems that this is fairly inefficient since it's
	// being executed up to 10 times per second.. So perhaps
	// figure out a better way to do this which is more optimized?
	
	Location * loc = [mapView locationForMousePosition];
	
	int positionFormat = [[NSUserDefaults standardUserDefaults] 
							integerForKey:@"PositionFormat"];
	
	NSString * s;
	
	LatLon * lat = [loc latitude];
	LatLon * lon = [loc longitude];
	
	//figure out the string depending on the user's preference of position formats
	if (loc) {
		switch (positionFormat) {
			case P_DEG:
				s = [NSString stringWithFormat:
					@"%.5f, %.5f", [[loc latitude] doubleDegrees],
					[[loc longitude] doubleDegrees] ];				
				break;
			case P_DEGMIN:
				s = [NSString stringWithFormat:
					@"%d %.3f, %d %.3f", [lat intDegrees],
					[lat floatMinutes], [lon intDegrees], [lon floatMinutes ]];				
				break;
			case P_DEGMINSEC:
				s = [NSString stringWithFormat:
					@"%d %d %.2f, %d %d %.2f", [lat intDegrees],
					[lat intMinutes], [lat floatSeconds],
					[lon intDegrees], [lon intMinutes], [lon floatSeconds ]];				
				break;
			case P_UTM:
				s = [NSString stringWithFormat:
					@"N %.0f E %.0f Z %d", [loc northing],
					[loc easting], [loc zoneNumber]];
				break;
			default:
				s = [NSString stringWithFormat:
					@"%.5f, %.5f", [[loc latitude] doubleDegrees],
					[[loc longitude] doubleDegrees] ];
				break;
		}
		
		//display the position in the floating info window.
		[infoWindowField setStringValue:s];
	}
}





#pragma mark -
#pragma mark Action methods

// Prints the current map view.
- (IBAction)print:(id)sender {
	[[NSPrintOperation printOperationWithView:mapView] runOperation];
}

- (IBAction)abort:(id)sender {
	[mapSource abort];
}


- (IBAction)zoomOut:(id)sender {
	int currentZoom = [zoomSlider intValue];
	[mapSource zoomOut];
	int newZoom = [mapSource zoom];
	if (newZoom != currentZoom) {
		[zoomSlider setIntValue:newZoom];		
		[self go:sender];
	}
}


- (IBAction)zoomIn:(id)sender {
	int currentZoom = [zoomSlider intValue];
	[mapSource zoomIn];
	int newZoom = [mapSource zoom];
	if (newZoom != currentZoom) {
		[zoomSlider setIntValue:newZoom];		
		[self go:sender];
	}
}


- (void)setPositionToMouseLocation {
	if (mouseClickLocation == nil) return;
	
	Waypoint * wpt = [Waypoint waypointWithLocation:mouseClickLocation];
	
	[self updatePositionWithWaypoint:wpt];
}

- (IBAction)centerOnMouseLocation:(id)sender {
	[self setPositionToMouseLocation];
	[self gotoWaypoint:nil];
}


- (IBAction)zoomOutOnMouseLocation:(id)sender {
	[self setPositionToMouseLocation];
	[self zoomOut:sender];
}

- (IBAction)zoomInOnMouseLocation:(id)sender {
	[self setPositionToMouseLocation];
	[self zoomIn:sender];
}

- (IBAction)addBookmarkAtMouseLocation:(id)sender {
	bookmarkType = BookmarkMouseLocation;
	
	[self showBookmarkSheet:sender];
}

- (IBAction)addBookmark:(id)sender {
	bookmarkType = BookmarkBrowserLoction;
	
	[self showBookmarkSheet:sender];
}


// adds a waypoint to the selected file (from the popup menu)
- (IBAction)addWaypointAtMouseLocationToDocument:(id)sender {
	if (!([sender isMemberOfClass:[NSMenuItem class]])) {
		return;
	}
	
	bookmarkType = AddWaypointAtMouseLocation;

	if (mouseClickLocation == nil) return;
	
//	Waypoint * wpt = [Waypoint waypointWithLocation:mouseClickLocation];
	
	id cont = [NSDocumentController sharedDocumentController];
	NSArray * docs = [cont documents];
	
	NSEnumerator * e = [docs objectEnumerator];
	id obj, doc;
	while (obj = [e nextObject]) {
		if ([[obj displayName] isEqualToString:[sender title]]) {
			doc = obj;
		}
	}
	
	if (doc == nil) return;
	
	docToAddWptTo  = [doc retain];
	
	[self showBookmarkSheet:sender];
	
}


- (void)fillPopupFileList {	
	id cont = [NSDocumentController sharedDocumentController];
	NSArray * docs = [cont documents];
	
	NSMenu * openFilesMenu = [[NSMenu alloc] init];
	NSMenuItem * newItem;
	
	NSEnumerator * e = [docs objectEnumerator];
	id obj;
	while (obj = [e nextObject]) {
		
		newItem = [[NSMenuItem alloc] initWithTitle:[obj displayName] 
											 action:@selector(addWaypointAtMouseLocationToDocument:)
									  keyEquivalent:@""];
		[newItem setTarget:self];
		
		[openFilesMenu addItem:newItem];
		[newItem release];
	}
	
	[mapContextualMenu setSubmenu:openFilesMenu forItem:openfilesMenuOutlet];
	[openFilesMenu release];
}



- (IBAction)showBookmarkSheet:(id)sender {
	[NSApp beginSheet: bookmarkSheet
			modalForWindow: [self window]
			modalDelegate: nil
			didEndSelector: nil
			contextInfo: nil];
	
	[NSApp runModalForWindow: bookmarkSheet];
		
	[NSApp endSheet: bookmarkSheet];
	[bookmarkSheet orderOut: self];
}


- (IBAction)closeBookmarkSheet:(id)sender {	
    [NSApp stopModal];
	
	if ([[sender title] isEqualToString:@"Add"]) {
		// actually add the bookmark/waypoint.
		[self bookmarkSheetDone];
	}
}

// called when the user closes the bookmark/waypoint sheet
- (void)bookmarkSheetDone {
	
	Waypoint * wpt = [[[Waypoint alloc] init] autorelease];
	
	[wpt setName:[bookmarkNameField stringValue]];
	
	switch ((BookmarkModeType) bookmarkType) {
		case BookmarkMouseLocation:
			// add a bookmark at the current mouse location
			[wpt setLocation:mouseClickLocation];
			[appController addBookmark:wpt];
			break;
		case BookmarkBrowserLoction:
			// add a bookmark at the browser's current location
			[wpt setLocation:[mapSource location]];
			[appController addBookmark:wpt];
			break;
		case AddWaypointAtMouseLocation:
			// add a waypoint at the current mouse location
			// to the document indicated by docToAddWptTo.
			[wpt setLocation:mouseClickLocation];
			
			if (docToAddWptTo) {
			
				[docToAddWptTo addPassedWaypoint:wpt];
				
				[docToAddWptTo release];
				docToAddWptTo = nil;
			}
				
			break;
	}

	//refresh the map so the waypoint/bookmark shows up.
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOODoRefreshMapView" object:nil];		
	
}


//the following actions should be called when the user edits one of the position
//fields in the toolbar.  They should update the position and then update all of the
//text fields accordingly.

- (IBAction)updatePositionWithFormattedField:(id)sender {
	double lat = [[formattedLatField objectValue] doubleDegrees];
	double lon = [[formattedLonField objectValue] doubleDegrees];
	
	Waypoint * wpt = [Waypoint waypointWithDoubleLatitude:lat
										  doubleLongitude:lon];
	[self updatePositionWithWaypoint: wpt];
}



- (IBAction)updatePositionWithUTM:(id)sender {
	Ellipsoid * ellip = [[Ellipsoid alloc] init];  //just use the default one for now.
		
	//***note, I am arbitrarily picking 'S' as the zoneLetter.. The only thing it really 
	//seems to matter for in this case is knowing whether or not it's north or south of the equator.
	Location * loc = [[[Location alloc] initWithNorthing:[northingField floatValue] 
										easting:[eastingField floatValue] 
								zoneLetter:'S' zoneNumber:[zoneNumberField intValue]
											  ellipsoid:ellip] autorelease];
	
	Waypoint * wpt = [Waypoint waypointWithLocation:loc];
	[ellip release];
	[self updatePositionWithWaypoint: wpt];
}


- (IBAction)toggleInfoWindow:(id)sender {
	if ([infoWindow isVisible]) {
		//[infoWindowMenuItem setTitle:@"Show Info Window"];
		[infoWindowMenuItem setState:NO];
		[infoWindow close];
		
		// Stop the timer.
		[self startInfoWindowTimer:NO];
	} else {
		//[infoWindowMenuItem setTitle:@"Hide Info Window"];
		[infoWindowMenuItem setState:YES];
		[infoWindow makeKeyAndOrderFront:self];

		// Start a periodic timer to update the info window display.
		[self startInfoWindowTimer:YES];
	}
}


// Called if the user presses the find button in the toolbar.
- (IBAction)findButtonPressed:(id)sender {
	[appController showAddressSearch];
}


- (void)reload {
	[self go:self];
}

// called when the user clicks on the go button in the toolbar.
- (IBAction)go:(id)sender {
	[self adjustMaximumZoomLevel];		// so the slider doesn't go to far.
	[self gotoWaypoint:waypointToGoto];	
}

- (IBAction)gotoBuiltInBookmark:(id)sender {
	Waypoint * wpt = [[Waypoint alloc] init];
	
	switch ([sender tag]) {
		case 0:		//b52 bombers
			[wpt setDoubleLatitude:32.15113];
			[wpt setDoubleLongitude:-110.82821];
			break;
		case 1:		//golden gate bridge
			[wpt setDoubleLatitude:37.81838];
			[wpt setDoubleLongitude:-122.47826];
			break;
		case 2:		//hoover dam
			[wpt setDoubleLatitude:36.01521];
			[wpt setDoubleLongitude:-114.73851];			
			break;
		case 3:		//statue of liberty
			[wpt setDoubleLatitude:40.68907];
			[wpt setDoubleLongitude:-74.04462];
			break;
		case 4:		//yosemite
			[wpt setDoubleLatitude:37.70129];
			[wpt setDoubleLongitude:-119.65879];			
			break;
		case 5:		//crater lake
			[wpt setDoubleLatitude:42.94078];
			[wpt setDoubleLongitude:-122.10810];
			break;
		case 6:		//pyramid
			[wpt setDoubleLatitude:36.09551];
			[wpt setDoubleLongitude:-115.17620];
			break;
		case 7:		//space needle
			[wpt setDoubleLatitude:47.620118];
			[wpt setDoubleLongitude:-122.348959];
			break;
		case 8:		//buckingham fountain
			[wpt setDoubleLatitude:41.876479];
			[wpt setDoubleLongitude:-87.619002];
			break;
				
	}
	
	[self updatePositionWithWaypoint:wpt];
	[self gotoWaypoint:wpt];
}




//called by the buttons in the toolbar.
- (IBAction)moveDirection:(id)sender {
	[mapSource moveLocationInDirection:[sender tag]];
	
	[self updatePositionWithWaypoint:[Waypoint waypointWithLocation:[mapSource location]]];
	[self gotoWaypoint:waypointToGoto];
}


- (IBAction)setBrowseOffline:(id)sender {
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	BOOL state = [browseOfflineCheck state];
	
	[browseOfflineCheck setState:(!state)];
	
	//record the fact that this is no longer the first launch.
	[defaults setBool:!state forKey:@"BrowseOffline"];
}


- (IBAction)sendUpdatePrefsNotification:(id)sender {
	//post a notification to let observers know that the user just updated their prefs.
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOUserPrefsUpdated" object:self];	
}


// This feature was requested by "Webmaster Clay"
// It sends the URL of the current tile to the Avant Go web page for people to download it to their PDA's.
- (IBAction)sendCurrentLocationAvantGo:(id)sender {
	NSMutableString * loc;
	
	NSURL * url = [mapSource centerTerraserverURL];

	loc = [NSMutableString stringWithString:[url absoluteString]];
//	[loc replaceOccurrencesOfString:@"image.aspx" 
//						 withString:@"tile.aspx" 
//							options:nil range:NSMakeRange(0, [loc length])];
	
	// The URL Clay sent me is in Java Script, but this is basically so the URL can be "escaped" 
	// meaning that the symbols are replaced.. I figured out how to do this by hand (see below), hence
	// Java Script is not necessary anymore.  This is good because it makes it work with Safari.
	[loc replaceOccurrencesOfString:@":" withString:@"%3A" options:nil range:NSMakeRange(0, [loc length])];
	[loc replaceOccurrencesOfString:@"/" withString:@"%2F" options:nil range:NSMakeRange(0, [loc length])];
	[loc replaceOccurrencesOfString:@"?" withString:@"%3F" options:nil range:NSMakeRange(0, [loc length])];
	[loc replaceOccurrencesOfString:@"=" withString:@"%3D" options:nil range:NSMakeRange(0, [loc length])];
	[loc replaceOccurrencesOfString:@"&" withString:@"%26" options:nil range:NSMakeRange(0, [loc length])];
						
	NSString * urlString = [NSString stringWithFormat:@"http://my.avantgo.com/account/edit_sub.html?url=%@&title=%@", loc, @"Terrabrowser_Image"];	

	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}




#pragma mark -
#pragma mark Notifications


// called whenever some progress has been made downloading the map
// from whatever the current model is
- (void)mapDownloadProgress:(NSNotification *)note {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	switch (downloadMode) {
		//case DOWNLOAD_NORMAL:
		case 0:
			[nc postNotificationName:@"MOODoRefreshMapView" object:[note object]];
			break;
		case 1:
			[downloadProgress setDoubleValue:[mapSource percentDone]];
			break;
	}
	
//	NSLog(@"download progress");
}

// called when the map is finished downloading
- (void)mapDownloadFinished:(NSNotification *)note {
//	NSLog(@"download finished");

	if (nil == note) return;
	
	if (downloadMode == DOWNLOAD_REGION) {
		// save the completed image as a JPEG file.
		
		NSImage * image = [note object];

		if (nil == image) return;
		
		NSString * path = [NSString stringWithString:@"~/Desktop/terrabrowser-region-download.jpg"];
		
		// save as JPEG
		NSDictionary* properties =
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat: [downloadQualitySlider floatValue]],
				NSImageCompressionFactor, NULL];    
		
		NSBitmapImageRep * bitmapRep = [NSBitmapImageRep imageRepWithData: [[image image] TIFFRepresentation]];
		NSData * bitmapData = [bitmapRep representationUsingType:NSJPEGFileType
										  properties:properties];
		
		[bitmapData writeToFile:[path stringByExpandingTildeInPath]
			   atomically:YES];
		
		// close the download window.
		[downloadProgress setDoubleValue:0.0];
		[downloadWindow orderOut:self];
	}
}



- (void)mapViewKeyDown:(NSNotification*)note {
	//gets called when the user presses a key while in the MapView
}


- (void)gotoWaypointNotification:(NSNotification*)note { 
	//note, it's okay here if the note is nil.. Don't worry about it - just
	//reload the picture. This will be used by the MapView when the user uses
	//the keyboard to scroll
	
	Waypoint * wpt;
	if (nil == note) wpt = nil;
	else wpt = [note object];
	
	[self updatePositionWithWaypoint:wpt];
	[self gotoWaypoint:waypointToGoto];
}



- (void)updatePlaceAndDate:(NSNotification*)note {
	
	NSString * newTitle = [NSString stringWithFormat:@"%@ (%@)",
		[mapSource placeName], [mapSource date] ];
	
	NSWindow * w = [self window];
	
	[w setTitle:newTitle];
	[w display];
	
}


#pragma mark -
#pragma mark Delegate methods


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize {
	//[self gotoWaypoint:nil];
//	NSLog(@"windowWillResize");
	return proposedFrameSize;
}


- (void)windowDidResize:(NSNotification *)aNotification {
	//[mapView didMoveOrResize];
//	NSLog(@"didresize");
	// use didEndLiveResize in the MapView instead
//	[self createNewMapSourceIfNeeded];
}

- (void)windowWillClose:(NSNotification *)aNotification {
	if ([aNotification object] == infoWindow) {
		//the info window is closing, so stop the timer
		[self startInfoWindowTimer:NO];
		[infoWindowMenuItem setTitle:@"Show Info Window"];
	}
	
}



- (void)applicationWillTerminate:(NSNotification *)aNotification {

	//do this so the position and size of the window will be saved.
	[[self window] saveFrameUsingName: @"BrowserWindowFrame"];
	
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	//record the fact that this is no longer the first launch.
	[defaults setBool:YES forKey:@"PrefsValid"];
	
	//save some settings..
	[defaults setInteger:[zoomSlider intValue] forKey:@"BrowserZoom"];
	
	[defaults setInteger:[self selectedType] forKey:@"MapTypeTag"];
	
	[defaults setFloat:[[formattedLatField objectValue] doubleDegrees] forKey:@"BrowserLatitude"];	
	[defaults setFloat:[[formattedLonField objectValue] doubleDegrees]forKey:@"BrowserLongitude"];
	
}


// called when a menu is about to be drawn (probably the contextual menu)
- (void)menuNeedsUpdate:(NSMenu *)menu {
	if (menu == mapContextualMenu) {
		// then it's the context menu from the map view
		
		// need to record the location where the user clicked the mouse,
		// otherwise we'll add the waypoint or zoom in on the wrong place.
		mouseClickLocation = [mapView locationForMousePosition];
		
		[self fillPopupFileList];
	}
	
	
}


#pragma mark -
#pragma mark AppleScript

- (id)handleReloadCommand:(NSScriptCommand *)command {
	[self reload];
	return nil;
}


- (void)dealloc {
	
	[mapSource release];
	
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: self];
	[theToolbar release];
	
	if (infoTimer != nil) [infoTimer release];
	
	[super dealloc];
}


@end
