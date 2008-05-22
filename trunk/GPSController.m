//
//  GPSController.m
//  GPSTest
//
//  Created by Ryan on Fri June 4 2004.
//  Copyright (c) 2004 Chimoosoft. All rights reserved.
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

#import "GPSController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"

#import "NMEAPacket.h"
#import "Location.h"
#import "Waypoint.h"
#import "XMLElement.h"
#import "GarminSerial.h"
#import "NMEASerial.h"
#import "GPSConstants.h"

@implementation GPSController


#pragma mark -
#pragma mark Generic methods

- (void)awakeFromNib {	
	[self fillPopupMenu:self];

	connected = NO;
	
	[protocolMenu setAutoenablesItems:YES];
	[protocolMenu setDelegate:self];
	
	[portMenu setAutoenablesItems:YES];
	[portMenu setDelegate:self];
	
	// set up the protocol menu so the items are enabled
	NSEnumerator * e = [[protocolMenu itemArray] objectEnumerator];
	id obj;
	while (obj = [e nextObject]) {
		if (! [[obj title] isEqualToString:@"Magellan"]) {
			[obj setTarget:self];
			[obj setAction:@selector(selectMenuItem:)];
		}
	}
		

	NMEACtl = [[NMEASerial alloc] init];
	garminCtl = [[GarminSerial alloc] init];
	
	[garminCtl setDelegate:self];
	[NMEACtl setDelegate:self];
	

}


- (IBAction)connect:(id)sender {
	
	int tag = [self protocolTag];
	
	[connectMenuItem setAction:@selector(disconnect:)];
	[connectMenuItem setTarget:self];
	[connectMenuItem setTitle:@"Disconnect"];
	
	NSString * pname;
	NSArray* items = [portMenu itemArray];
	NSEnumerator * e = [items objectEnumerator];
	id obj;
	while (obj = [e nextObject]) {
		if ([obj state] == NSOnState) {
			pname = [obj title];
		}
	}
	
	[NMEACtl setPortName:pname];
	[garminCtl setPortName:pname];
	
	[GPSInfoWindow makeKeyAndOrderFront:sender];
	
	if (tag == 0) { // NMEA
		[NMEACtl connect];
		connected = YES;
	} else if (tag == 1) { // Garmin
		[garminCtl connect];
		// connected = YES is set in the GPSConnected delegate method
	}
}


- (IBAction)disconnect:(id)sender {
	int tag = [self protocolTag];

	[connectMenuItem setAction:@selector(connect:)];
	[connectMenuItem setTarget:self];
	[connectMenuItem setTitle:@"Connect"];
	
	if (tag == 0) { // NMEA
		[NMEACtl disconnect];
		connected = NO;
	} else if (tag == 1) { // Garmin
		[garminCtl disconnect];
		connected = NO;
	}
}

- (IBAction)listDevices:(id)sender {	
	[self fillPopupMenu];
}


// fill the popup menu with a listing of serial ports
- (IBAction)fillPopupMenu:(id)sender {
	// first, empty the port menu
	
	NSArray * array = [[portMenu itemArray] copy];
	NSEnumerator * e = [array objectEnumerator];
	id item;
	while (item = [e nextObject]) {
		[portMenu removeItem:item];
	}
	[array release];
	
	// now fill it
	
	NSEnumerator * enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort * aPort;
	NSString * title;
	
	int i = 0;
	int indexToSelect = 0;
	while (aPort = [enumerator nextObject]) {
		if (aPort == nil) break;
		
		title = [aPort bsdPath];
		
		// see if it's the keyspan adapter
		NSRange range = [title rangeOfString:@"USA"];
		if (range.location != NSNotFound) {
			indexToSelect = i;
		}
	
		item = [[[NSMenuItem alloc] init] autorelease];
		[item setState:NSOffState];
		[item setTitle:title];
		[item setTarget:self];
		[item setAction:@selector(selectMenuItem:)];
		
		[portMenu addItem:item];
		
		i++;
	}

	/*  // doesn't seem to work.. maybe you hove to have it plugged in
		// before the program launches?
	// now, add a refresh item
	item = [[[NSMenuItem alloc] init] autorelease];
	[item setState:NSOffState];
	[item setTitle:@"Refresh List"];
	[item setTarget:self];
	[item setAction:@selector(fillPopupMenu:)];
	
	[portMenu addItem:item];
	*/
		
	// select the most likely serial port to use (for now, just keyspan,
	// later, remember in prefs)
	if ([portMenu numberOfItems] > 0) {
		[[portMenu itemAtIndex:indexToSelect]
		setState:NSOnState];		
	}
		
}


- (IBAction)selectMenuItem:(id)sender {
	if ([sender isMemberOfClass:[NSMenuItem class]]) {
		id parent = [sender menu];
		
		// turn off all the other items in the menu
		id item;
		NSEnumerator * e = [[parent itemArray] objectEnumerator];
		while (item = [e nextObject]) {
			[item setState:NSOffState];
		}
		
		// turn on this item
		[sender setState:NSOnState];
	}
	
}


#pragma mark -
#pragma mark Garmin methods


- (IBAction)downloadWaypoints:(id)sender {
	[GPSInfoWindow makeKeyAndOrderFront:sender];
	transferType = Wpt_Transfer;
	[garminCtl downloadWaypoints];	
}

- (IBAction)downloadTracks:(id)sender {
	[GPSInfoWindow makeKeyAndOrderFront:sender];
	transferType = Trk_Transfer;	
	[garminCtl downloadTracks];
}

- (IBAction)downloadRoutes:(id)sender {
	[GPSInfoWindow makeKeyAndOrderFront:sender];
	transferType = Rte_Transfer;
	[garminCtl downloadWaypoints];	
}


- (IBAction)abortTransfer:(id)sender {
	
	// if we're aborting the transfer, we still want to get 
	// all the downloaded items up to this point

	[garminCtl abortTransfer];
	
	switch(transferType) {
		case Wpt_Transfer:
			[self GPSFinishedWaypointDownload:[garminCtl waypointList]];
			break;
		case Trk_Transfer:
			[self GPSFinishedTracklogDownload:[garminCtl trackList]];
			break;
		case Rte_Transfer:
			break;
	}
	

}

- (IBAction)startPVT:(id)sender {
	[pvtMenuItem setTitle:@"Stop PVT"];
	[pvtMenuItem setAction:@selector(stopPVT:)];
	[garminCtl startPVTMode];
}

- (IBAction)stopPVT:(id)sender {
	[pvtMenuItem setTitle:@"Start PVT"];
	[pvtMenuItem setAction:@selector(startPVT:)];
	[garminCtl stopPVTMode];
}


- (IBAction)tempSendWpt:(id)sender {
	Waypoint * wpt = [Waypoint waypointWithDoubleLatitude:30.12345 
										  doubleLongitude:-120.12345];
	[wpt setName:@"AATEST"];
	[wpt setSymbolName:@"Residence"];
	[wpt setElevation:[NSNumber numberWithFloat:155.1234]];
	
	Waypoint * wpt2 = [Waypoint waypointWithDoubleLatitude:12.12345 
										   doubleLongitude:123.12345];
	
	[wpt2 setName:@"AATEST2"];
	[wpt2 setSymbolName:@"Fishing"];
	[wpt2 setElevation:[NSNumber numberWithFloat:10.0]];
	
	NSArray * array = [NSArray arrayWithObjects:wpt, wpt2, nil];
	
	[garminCtl uploadWaypoints:array];
}


// add a message to the log
- (void)logMessage:(NSString*)msg {
	[outputTextView insertText:msg];
}



#pragma mark -
#pragma mark Garmin delegate methods
- (void)GPSLocationUpdated:(Location*)loc {
	NSLog(@"location updated called, loc = %f, %f.", [loc doubleLatitude], [loc doubleLongitude]);
	
	[latField setObjectValue:[loc latitude]];
	[lonField setObjectValue:[loc longitude]];
	
}


- (void)GPSDownloadProgress:(int)currentItem
					  outOf:(int)numItems 
				currentName:(int)itemName {

	[progressBar setMaxValue:numItems];
	[progressBar setDoubleValue:currentItem];
	
	
	if ((itemName == nil) || ([itemName isEqualToString:@""])) {
		[progressNameField setStringValue:lastItemName];
	} else {
		lastItemName = itemName;
		[progressNameField setStringValue:itemName];
	}
	
	//NSLog(@"GPSDownloadProgress, %d out of %d, name = %@", currentItem, numItems, itemName);
	
}


- (void)GPSFinishedWaypointDownload:(XMLElement*)waypointList {
	[self logMessage:@"Finished waypoint download."];
	
	id docCont = [NSDocumentController sharedDocumentController];
	
	id newDoc = [docCont makeUntitledDocumentOfType:@"GPXType"];
	[newDoc setWaypointList:waypointList];
	
	[docCont addDocument:newDoc];
	
	[newDoc makeWindowControllers];
	[newDoc showWindows];

	NSLog(@"Finished waypoint download");
}

- (void)GPSFinishedTracklogDownload:(XMLElement*)trackList {

	// for now, just insert them into the front most document.. 
	// warning - this will overwrite any tracklogs in the front most document.
	// should do an alert, or mabye put the download button it the document window itself.
	id docCont = [NSDocumentController sharedDocumentController];	
	id doc = [docCont currentDocument];
	
	[doc setTrackList:trackList];
	
	NSLog(@"Finished tracklog download");
}


- (void)GPSConnected {
	connected = YES;
	[GPSNameField setStringValue:[garminCtl GPSName]];
}

#pragma mark -
#pragma mark NMEA methods


// called when we receive a new packet
- (void)NMEAStartOfNewPacket:(NMEAPacket*)packet {
	[fixField setStringValue:[NSString stringWithFormat:@"%dD", [packet gpsFix]]];
	[numSatellitesField setIntValue:[packet numSatellites]];	
	[elevationField setFloatValue:[packet elevation]];	
	[magBearingField setFloatValue:[packet magneticBearing]];	
	[trueBearingField setFloatValue:[packet trueBearing]];	
	[CMGField setFloatValue:[packet courseMadeGood]];	
	[horizErrorField setFloatValue:[packet horizontalError]];	
	[vertErrorField setFloatValue:[packet verticalError]];	
}



#pragma mark -
#pragma mark Other methods

// return the tag of the currently selected protocol
- (int)protocolTag {
	int tag = 0;
	NSArray* items = [protocolMenu itemArray];
	NSEnumerator * e = [items objectEnumerator];
	id obj;
	while (obj = [e nextObject]) {
		if ([obj state] == NSOnState) {
			tag = [obj tag];
		}
	}
	
	return tag;
}



- (BOOL)validateMenuItem:(NSMenuItem*)anItem {
	id menu = [anItem menu];
	
	if ((menu == portMenu) || (menu == protocolMenu)) {
		return (! connected);
	}
	
	return YES;
}


- (void)dealloc {
	[garminCtl release];
	[NMEACtl release];
	
	[super release];
}



@end
