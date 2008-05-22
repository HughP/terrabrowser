//
//  GPSController.h
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

//
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

#import "GPSConstants.h"

@class GarminSerial;
@class NMEASerial;
@class XMLElement;
@class NMEAPacket;
@class Location;

@interface GPSController : NSObject {

	IBOutlet NSTextView * outputTextView;
	
	IBOutlet id numSatellitesField;
	IBOutlet id fixField;
	IBOutlet id latField;
	IBOutlet id lonField;
	IBOutlet id elevationField;
	IBOutlet id magBearingField;
	IBOutlet id trueBearingField;
	IBOutlet id CMGField;
	IBOutlet id horizErrorField;
	IBOutlet id vertErrorField;
	
	IBOutlet id progressBar;
	IBOutlet id progressNameField;
	
	IBOutlet id baudMenu;
	
	IBOutlet id pvtMenuItem;
	
	IBOutlet id portMenu;
	IBOutlet id protocolMenu;
	
	IBOutlet id connectMenuItem;
	
	IBOutlet id GPSNameField;
	

	IBOutlet id GPSInfoWindow;
	
	GPSTransferType transferType;
	
	GarminSerial * garminCtl;
	NMEASerial * NMEACtl;
	
	NSString * lastItemName;
	
	BOOL connected;
}


#pragma mark -
#pragma mark Generic methods


- (IBAction)disconnect:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)listDevices:(id)sender;
- (IBAction)fillPopupMenu:(id)sender;

- (void)logMessage:(NSString*)msg;

#pragma mark -
#pragma mark Garmin methods

- (IBAction)downloadWaypoints:(id)sender;
- (IBAction)downloadTracks:(id)sender;
- (IBAction)downloadRoutes:(id)sender;

- (IBAction)abortTransfer:(id)sender;
- (IBAction)startPVT:(id)sender;
- (IBAction)stopPVT:(id)sender;
- (IBAction)tempSendWpt:(id)sender;

// delegate methods
- (void)GPSFinishedTracklogDownload:(XMLElement*)trackList;
- (void)GPSFinishedWaypointDownload:(XMLElement*)waypointList;

- (void)GPSDownloadProgress:(int)currentItem outOf:(int)numItems currentName:(int)itemName;
	
- (void)GPSLocationUpdated:(Location*)loc;
- (void)GPSConnected;

#pragma mark -
#pragma mark NMEA methods

- (void)NMEAStartOfNewPacket:(NMEAPacket*)packet;

#pragma mark -
#pragma mark Other methods

- (BOOL)validateMenuItem:(NSMenuItem*)anItem;
	
@end
