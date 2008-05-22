//
//  AppController.h
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

@class WaypointDocument;
@class Waypoint;
@class URLDataFetcher;

@interface AppController : NSObject {
	BOOL alreadyAwoke;	
	NSUserDefaults * defaults;
		
	IBOutlet id browserWindow;
	IBOutlet id browserController;
	
	//for the about panel
	IBOutlet id aboutPanel;
	IBOutlet id aboutRegText;
	
	IBOutlet id urlField;
	IBOutlet id emailField;
	IBOutlet id donationView;
	
	//for the preferences window
	IBOutlet id preferencesWindow;
	
	IBOutlet id cacheCheck;
	IBOutlet id diskCacheField;
	IBOutlet id memCacheField;
	IBOutlet id baseURLField;
	
	IBOutlet id diskCacheUsedField;
	IBOutlet id memCacheUsedField;
	
	IBOutlet id positionFormatMatrix;
	IBOutlet id distanceFormatMatrix;
	//end of preferences section
	
	IBOutlet id addressSearchWindow;
	
	WaypointDocument * bookmarkDocument;
	IBOutlet id bookmarkMenu;
	IBOutlet id bookmarkSpacer;
	
	IBOutlet id userDefaultsController;
	
	URLDataFetcher * zipFetcher, * addressFetcher;
	
}

+ (void)initialize;
+ (NSArray*)globalFileList;

- (IBAction)resetBaseURL:(id)sender;
- (IBAction)enableCache:(id)sender;
- (IBAction)showPreferencesWindow:(id)sender;

- (IBAction)emptyCache:(id)sender;
- (IBAction)sendFeedback:(id)sender;

- (IBAction)openLicense:(id)sender;
- (IBAction)openReadme:(id)sender;

- (void)showAddressSearch;
- (IBAction)showAboutPanel:(id)sender;


#pragma mark -
#pragma mark Goto URL Methods

- (IBAction)showChimoosoftFAQPage:(id)sender;
- (IBAction)showChimoosoftDonationPage:(id)sender;
- (IBAction)showChimoosoftDisclaimerPage:(id)sender;
- (IBAction)showUSGSHomePage:(id)sender;
- (IBAction)showTerraserverHomePage:(id)sender;

#pragma mark -
#pragma mark Other methods

- (void)addBookmark:(Waypoint*)wpt;
- (IBAction)manageBookmarks:(id)sender;
- (IBAction)gotoWaypointMenuItem:(id)sender;
- (IBAction)showApplicationHelp:(id)sender;

- (IBAction)requestLocationForAddress:(id)sender;


@end
