//
//  AppController.m
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

#import "AppController.h"
#import "Constants.h"

#import "CMSDefaults.h"
#import "CMSCommon.h"

#import "URLDataFetcher.h"

#import "XMLFileHandler.h"

//for testing section
#import "Location.h"
#import "LatLon.h"
#import "Ellipsoid.h"

#import "Waypoint.h"
#import "WaypointDocument.h"

//end testing section


@interface AppController ()

- (void)setupDefaultPreferences;
- (void)setupBookmarkFile;
- (void)savePreferencesFromWindow;
- (void)updateCacheDisplay;
- (void)refreshBookmarkMenu;

- (void)requestLocationForZipCode:(NSString*)zip;
- (void)requestLocationForFullAddress:(NSString*)address city:(NSString*)city zip:(NSString*)zip;

@end


@implementation AppController

#pragma mark -
#pragma mark Class methods


// Automatically called at runtime, used to initalize any class
// variables, etc.
+ (void)initialize {

}

// Returns an array of WaypointDocuments so we can draw
// all the waypoints, tracklogs, etc. from them.
+ (NSArray*)globalFileList {
	return [[NSDocumentController sharedDocumentController] documents];
}


// Is this OS version at least 10.3.0?
+ (BOOL)systemIsPantherOrLater {
	SInt32 MacVersion;
	
	if (Gestalt(gestaltSystemVersion, &MacVersion) == noErr) {
		if (MacVersion < 0x1030) {
			return NO;
		}		
		return YES;
	}
	return NO;
}	

+ (NSString*)applicationPath {
	NSDictionary * appDictionary = [[NSWorkspace sharedWorkspace] activeApplication];
	NSString * appPath = [appDictionary objectForKey: @"NSApplicationPath"];
	return appPath;
}


#pragma mark -
#pragma mark Notifications and Delegates

- (void)awakeFromNib {	
	if (alreadyAwoke) return;
	alreadyAwoke = YES;
	
	[CMSCommon quitIfNotTiger];
	
	defaults = [NSUserDefaults standardUserDefaults];
	
	// Restore preferences, setup defaults, etc.
	[self setupDefaultPreferences];
		
	[self setupBookmarkFile];	
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

	// Show disclaimer message if they haven't turned it off
	if (! [defaults boolForKey:@"DontShowDisclaimer"]) {

		int iResponse = 
		NSRunCriticalAlertPanel(@"Please read the following warning about Terrabrowser.", 
								@"Although Terrabrowser is believed to be accurate, you are urged to use it for recreational purposes only. No guarantee is made as to the accuracy of coordinate conversions, correct positioning of waypoints, or any other critical aspect of the software. You agree to use this software at your own risk. \n\nThis is beta level software which has not been extensively tested and may not work in all cases.  Certain functionality is still missing at this point including full GPS support.  Other features such as tracklogs work but are still somewhat buggy.  To import your waypoints with this version of Terrabrowser, we suggest that you use MacGPSBabel - read the FAQ on our website for more information on this.  You should also back up your bookmarks if upgrading from a previous version of Terrabrowser.",
								@"OK", @"Disclaimer", /*ThirdButtonHere:*/nil
								/*, args for a printf-style msg go here */);
		switch(iResponse) {
			case NSAlertDefaultReturn:    /* user pressed OK */
				break;
			case NSAlertAlternateReturn:  /* user pressed second button */
				[self showChimoosoftDisclaimerPage:self];
				break;
			case NSAlertOtherReturn:      /* user pressed the third button */
				break;
			case NSAlertErrorReturn:      /* an error occurred */
				break;
		}
	}
	
	
	
	[browserWindow makeKeyAndOrderFront:self];

#if DEBUG	
	NSLog(@"reading xml");
	XMLFileHandler * xmlHandler = [[XMLFileHandler alloc] init];
	[xmlHandler readFile];
	[xmlHandler writeFile];
	[xmlHandler release];
#endif
	
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[browserController applicationWillTerminate:aNotification];
	
	[bookmarkDocument saveDocument:self];
	
	[self savePreferencesFromWindow];
}




// this allows us to set whether an "untitled" waypoint document will be
// automatically created or not when the program starts.
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return [defaults boolForKey:@"StartWithNewDocumentWindow"];
	
	
}

- (void)applicationDidResignActive:(NSNotification *)aNotification {
}


- (void)windowWillClose:(NSNotification *)aNotification {
	if ([aNotification object] == preferencesWindow) {
		[self savePreferencesFromWindow];
	}		
}

#pragma mark -
#pragma mark Preferences and Version Tracking


- (IBAction)showPreferencesWindow:(id)sender {
	if (nil == preferencesWindow) {
		if (![NSBundle loadNibNamed:@"Preferences.nib" owner:self] ) {
			NSLog(@"Load of Preferences.nib failed");
			return;
		}
	}
	
	[preferencesWindow setOneShot:YES];
	[preferencesWindow makeKeyAndOrderFront:nil];
	
	[self updateCacheDisplay];

}


- (void)savePreferencesFromWindow {
	
	// position format
	int tag = 0;
	if ([[positionFormatMatrix cellWithTag:P_DEG] state]) { tag = P_DEG; }
	if ([[positionFormatMatrix cellWithTag:P_DEGMIN] state]) { tag = P_DEGMIN; }
	if ([[positionFormatMatrix cellWithTag:P_DEGMINSEC] state]) { tag = P_DEGMINSEC; }
	if ([[positionFormatMatrix cellWithTag:P_UTM] state]) { tag = P_UTM; }
	
	[defaults setInteger:tag forKey:@"PositionFormat"];
	
	if ([[distanceFormatMatrix cellWithTag:0] state]) { 
		// metric
		[defaults setBool:YES forKey:@"MetricDistance"];
	} else {
		// english
		[defaults setBool:NO forKey:@"MetricDistance"];
	}
	
	// set up the browser cache..
	NSURLCache * cache = [NSURLCache sharedURLCache];
	[cache setDiskCapacity:(1048576*[diskCacheField floatValue])];
	[cache setMemoryCapacity:(1048576*[memCacheField floatValue])];
	
	// post a notification to let observers know that the user just updated their prefs.
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOUserPrefsUpdated" object:self];	
}


- (void)setupDefaultPreferences {
	NSColor * c;
	
	if ([defaults boolForKey:@"PrefsValid"]) {
		
		//the default position format
		int tag = [defaults integerForKey:@"PositionFormat"];
		[positionFormatMatrix selectCellWithTag:tag];
		
		if ([defaults boolForKey:@"MetricDistance"]) {
			[distanceFormatMatrix selectCellWithTag:0];
		} else {
			[distanceFormatMatrix selectCellWithTag:1];
		}
		
	} else {
		// this must be the first launch..
		// register some default values
		
		c = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
		[defaults setObject:[NSArchiver archivedDataWithRootObject:c]
					 forKey:@"BrowserScaleBarColor"];		
		
		c = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:1.0];
		[defaults setObject:[NSArchiver archivedDataWithRootObject:c]
					 forKey:@"BrowserGridlineColor"];
		
		c = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0];
		[defaults setObject:[NSArchiver archivedDataWithRootObject:c]
					 forKey:@"BrowserTracklogColor"];
		
		c = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.0 alpha:1.0];
		[defaults setObject:[NSArchiver archivedDataWithRootObject:c]
					 forKey:@"BrowserRouteColor"];
		
		[defaults setBool:YES forKey:@"EnableCache"];
		[defaults setInteger:50 forKey:@"DiskCacheSize"];
		[defaults setInteger:10 forKey:@"MemoryCacheSize"];
		[defaults setBool:NO forKey:@"BrowseOffline"];
		[defaults setInteger:3 forKey:@"BrowserLineWidth"];
		[defaults setFloat:22.93 forKey:@"BrowserPathRenderingQuality"];
		[defaults setBool:YES forKey:@"BrowserShowRoutes"];
		[defaults setBool:YES forKey:@"BrowserShowTracklogs"];
		[defaults setBool:YES forKey:@"BrowserShowWaypoints"];
		[defaults setBool:YES forKey:@"BrowserShowScaleBar"];
		
		[defaults setInteger:10 forKey:@"BrowserZoom"];
		[defaults setInteger:30 forKey:@"TileTimeout"];
		
		[defaults setFloat:0.85 forKey:@"BrowserLineTransparency"];
		[defaults setBool:YES forKey:@"StartWithNewDocumentWindow"];
		[defaults setBool:YES forKey:@"WaypointShowDetailDrawerOnOpen"];
		
		[defaults setObject:@"http://tiger.census.gov/cgi-bin/mapsurfer?infact=2&outfact=2&act=move&tlevel=-&tvar=-&tmeth=i&mlat=&mlon=&msym=bigdot&mlabel=&murl=&lat=%f&lon=%f&wid=0.360&ht=0.130&conf=mapnew.con"
					 forKey:@"BrowserCustomURL"];
		
		
		[self resetBaseURL:self];
	}
	
	
	//this also sends out the prefsupdated notification and sets the cache size.
	[self savePreferencesFromWindow];	
}


#pragma mark -
#pragma mark Assorted methods


// Resets base url to default
- (IBAction)resetBaseURL:(id)sender {
	// Set the base URL for the Terraserver.
	[defaults setObject:@"http://terraserver-usa.com/" forKey:@"TerraserverBaseURL"];
}


#pragma mark -
#pragma mark Show methods

// Opens the users web browser and points it to the passed URL string.
- (void)gotoURL:(NSString*)urlString {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)showChimoosoftFAQPage:(id)sender { 
	[self gotoURL:@"http://www.chimoosoft.com/faq.html"];
}

- (IBAction)showChimoosoftDonationPage:(id)sender {
	[self gotoURL:@"http://www.chimoosoft.com/donations/"];
}

- (IBAction)showChimoosoftDisclaimerPage:(id)sender {
	[self gotoURL:@"http://www.chimoosoft.com/disclaimer.html"];
}


- (IBAction)showUSGSHomePage:(id)sender {
	[self gotoURL:@"http://www.usgs.gov/"];
}
- (IBAction)showTerraserverHomePage:(id)sender {
	[self gotoURL:@"http://www.terraserver-usa.com/"];
}

// Open the EULA
- (IBAction)openLicense:(id)sender {	
	[CMSCommon openFileInBundle:@"/Contents/Resources/Chimoosoft_License.rtf"];
}


- (IBAction)openReadme:(id)sender {
	[CMSCommon openFileInBundle:@"/Contents/Resources/readme.rtfd"];
}


- (IBAction)sendFeedback:(id)sender {
	NSString * body = [NSString stringWithFormat:@"Terrabrowser Version %@\nMac OS X %@", [CMSCommon applicationVersionString], [CMSCommon operatingSystemVersionString]];
	[CMSCommon composeEmailTo:@"support@chimoosoft.com"
				  withSubject:[NSString stringWithFormat:@"Terrabrowser %@ Support", [CMSCommon applicationVersionString]]
					  andBody:body];	
}


//show the about panel to the user.
- (IBAction)showAboutPanel:(id)sender {
	if (aboutPanel == nil) {  //to make sure we don't repeatedly load it.
		if (![NSBundle loadNibNamed:@"AboutPanel.nib" owner:self] ) {
			NSLog(@"Load of AboutPanel.nib failed");
			return;
		}
	}
	
	
	[aboutPanel makeKeyAndOrderFront:nil];
//	[urlField setURLToShow:
//		[NSURL URLWithString: @"http://www.chimoosoft.com/"]];
//	[emailField setURLToShow:
//		[NSURL URLWithString: @"mailto:support@chimoosoft.com"]];
	
//	[donationView setURLToShow:
//		[NSURL URLWithString: @"http://www.chimoosoft.com/donations/"]];
}


- (IBAction)showApplicationHelp:(id)sender {
	NSRunAlertPanel(@"Terrabrowser Help",
					@"Help is not built in to this version of Terrabrowser.  Please consult the readme file and read the FAQ on the Chimoosoft web site for help.",
					@"OK", nil, nil);	
}


#pragma mark -
#pragma mark Caching methods


- (void)updateCacheDisplay {
	NSURLCache * cache = [NSURLCache sharedURLCache];

	[diskCacheUsedField setStringValue: 
		[NSString stringWithFormat:@"%.2f\tMB used", (float)([cache currentDiskUsage] / 1048576.0)]];
	[memCacheUsedField setStringValue:
		[NSString stringWithFormat:@"%.2f\tMB used", (float)([cache currentMemoryUsage] / 1048576.0)]];		
}

- (IBAction)emptyCache:(id)sender {
	NSURLCache * cache = [NSURLCache sharedURLCache];
	[cache removeAllCachedResponses];
	[self updateCacheDisplay];
}

// when the user clicks the enable cache checkbox.
- (IBAction)enableCache:(id)sender {
	BOOL b = [cacheCheck state];
	
	[memCacheField setEnabled:b];
	[diskCacheField setEnabled:b];
}



#pragma mark -
#pragma mark Address search methods


- (void)showAddressSearch { 
	[addressSearchWindow makeKeyAndOrderFront:self];
}

- (IBAction)requestLocationForAddress:(id)sender {
	[[sender window] orderOut:sender];
	
	NSString * cityStr = [defaults stringForKey:@"LastCitySearch"];
	NSString * addrStr = [defaults stringForKey:@"LastAddressSearch"];
	
	NSString * zip = [defaults stringForKey:@"LastZipCodeSearch"];
	NSMutableString * address = [NSMutableString stringWithCapacity:10];
	if ([addrStr length] > 1) {
		[address setString: addrStr];	
		[address replaceOccurrencesOfString:@" " 
								 withString:@"+" 
									options:nil 
									  range:NSMakeRange(0, [address length])];
	}
	
	NSMutableString * city = [NSMutableString stringWithCapacity:10];
	if ([cityStr length] > 1) {
		[city setString: cityStr];
		[city replaceOccurrencesOfString:@" " 
							  withString:@"+" 
								 options:nil 
								   range:NSMakeRange(0, [city length])];		
	}
	
	
	// if they've entered an address, city, and zip, then we can fetch precisely.
	if (([address length] <= 1) || ([city length] <= 1)) {
		[self requestLocationForZipCode: zip];
	} else {
		[self requestLocationForFullAddress:address
									   city:city 
										zip:zip];
	}
	
}

// Attempts to figure out the latitude and longitude for the zip code
// set by the user.
- (void)requestLocationForZipCode:(NSString*)zip {
	if (nil == zipFetcher) {
		zipFetcher = [[URLDataFetcher alloc] 
					initWithOwner:self selector:@selector(parseZipData)];				
	}
	
	NSString * urlString = [NSString stringWithFormat:@"http://zipinfo.com/cgi-local/zipsrch.exe?ll=ll&zip=%@&Go=Go", zip];
	[zipFetcher startTransferWithURL:[NSURL URLWithString:urlString]];
	
}


- (void)requestLocationForFullAddress:(NSString*)address city:(NSString*)city zip:(NSString*)zip {
	if (nil == addressFetcher) {
		addressFetcher = [[URLDataFetcher alloc] 
					initWithOwner:self selector:@selector(parseAddressData)];
	}
	
	NSString * urlString = [NSString stringWithFormat:@"http://www.maporama.com/share/map.asp?COUNTRYCODE=US&_XgoGCAddress=%@&Zip=%@&State=&_XgoGCTownName=%@&SEARCH_ADDRESS.x=18&SEARCH_ADDRESS.y=0", address, zip, city];
	[addressFetcher startTransferWithURL:[NSURL URLWithString:urlString]];	
}


// Parses the HTML page fetched from performing an address search and
// attempts to grab the latitude and longitude from the HTML code.
- (void)parseAddressData {
	
	NSString * html = [addressFetcher string];
	if (nil == html) return;
	
	int len = [html length];
	if (len <= 0) return;
	
	BOOL b;
	float lat, lon;
	
	NSScanner * scanner = [NSScanner scannerWithString:html];
	[scanner setCaseSensitive:NO];
	
	//try to parse out the date.
	b = [scanner scanUpToString:@"Lat-Long" intoString:nil];
	b = [scanner scanUpToString:@"SearchMapFontText\">" intoString:nil];
	
	[scanner setCharactersToBeSkipped:
		[[NSCharacterSet characterSetWithCharactersInString:@"-0123456789."] invertedSet]];
	
	// skip over the DMS data.
	b = [scanner scanInt:nil];
	b = [scanner scanInt:nil];
	b = [scanner scanInt:nil];
	b = [scanner scanInt:nil];
	b = [scanner scanInt:nil];
	b = [scanner scanInt:nil];
	
	b = [scanner scanFloat:&lat];
	b = [scanner scanFloat:&lon];
	
	if (!b) return;	
	
	if ((lat >= 0) && (lon <= 180)) {
		Waypoint * wpt = [Waypoint waypointWithDoubleLatitude:lat doubleLongitude:lon];
		[browserController updatePositionWithWaypoint:wpt];
		[browserController gotoWaypoint:wpt];
	}
	
}



// Parses the HTML page fetched from performing a zip code search and
// attempts to grab the latitude and longitude from the HTML code.
- (void)parseZipData {
	
	NSString * html = [zipFetcher string];
	if (nil == html) return;
	
	int len = [html length];
	if (len <= 0) return;
	
	BOOL b;
	float lat, lon;
	
	NSScanner * scanner = [NSScanner scannerWithString:html];
	[scanner setCaseSensitive:NO];
	
	//try to parse out the date.
	b = [scanner scanUpToString:@"Longitude" intoString:nil];
	b = [scanner scanUpToString:[defaults stringForKey:@"LastZipCodeSearch"]
					 intoString:nil];
	
	[scanner setCharactersToBeSkipped:
		[[NSCharacterSet characterSetWithCharactersInString:@"-0123456789."] invertedSet]];
	
	b = [scanner scanInt:nil];
	b = [scanner scanFloat:&lat];
	b = [scanner scanFloat:&lon];
	
	lon *= -1.0;  // since they'll always be negative in the US, but this site uses East/West 
				  // instead of positive and negative.
	
	if (!b) return;
	
	
	if ((lat >= 0) && (lon <= 180)) {
		Waypoint * wpt = [Waypoint waypointWithDoubleLatitude:lat doubleLongitude:lon];
		[browserController updatePositionWithWaypoint:wpt];
		[browserController gotoWaypoint:wpt];
	}
	
}



#pragma mark -
#pragma mark Bookmark methods


- (void)addBookmark:(Waypoint*)wpt {
	[bookmarkDocument addPassedWaypoint:wpt];
	[self refreshBookmarkMenu];
}


- (void)refreshBookmarkMenu {
	
	// Delete every menu item below the bookmarkSpacer, 
	// and then refill it from the bookmarkDocument.
	
	int spacerIndex = [bookmarkMenu indexOfItem:bookmarkSpacer];
	int i;
	int count = [bookmarkMenu numberOfItems];
	
	for (i = spacerIndex + 1; i < count; i++) {
		[bookmarkMenu removeItemAtIndex:spacerIndex + 1];
	}
	
	NSEnumerator * e = [[bookmarkDocument waypointArray] objectEnumerator];
	id obj;
	NSMenuItem * item;
	while (obj = [e nextObject]) {
		if ([obj name] != nil) {
			item = [[NSMenuItem alloc] initWithTitle:[obj name]
											  action:@selector(gotoWaypointMenuItem:)
									   keyEquivalent:@""];
			
			[bookmarkMenu addItem:item];			
		}		
	}
}

- (IBAction)gotoWaypointMenuItem:(id)sender {
	Waypoint * wpt = [bookmarkDocument waypointNamed:[sender title]];
	
	[browserController updatePositionWithWaypoint:wpt];
	[browserController gotoWaypoint:wpt];
}


- (void)setupBookmarkFile {
	
	// Grab the bookmark file which is stored in the Application Support folder.
	NSFileManager * manager = [NSFileManager defaultManager];
	
	NSString * path = [[NSString stringWithString: @"~/Library/Application Support/Terrabrowser"] stringByExpandingTildeInPath];
	BOOL isDirectory;
	BOOL dirExists = [manager fileExistsAtPath:path isDirectory:&isDirectory];
	
	if (!dirExists) {
		// Then we need to create the directory...
		[manager createDirectoryAtPath:path attributes:nil];
	}
	
	// Now, check for the bookmarks file.
	NSString * bookmarkPath = [path stringByAppendingPathComponent:@"bookmarks.gpx"];
	
	id docCont = [NSDocumentController sharedDocumentController];
//	NSString * type = @"GPXType";
	
	if (! [manager fileExistsAtPath:bookmarkPath]) {
		// The bookmark file doesn't exist yet, so copy a default one from the bundle
		
		NSString * copyFromPath = [AppController applicationPath];
		copyFromPath = [copyFromPath stringByAppendingString:@"/Contents/Resources/default_bookmarks.gpx"];
		
		[manager copyPath:copyFromPath toPath:bookmarkPath handler:nil];
	}
	
	if (! [manager fileExistsAtPath:bookmarkPath]) {
		NSLog(@"Can't find bookmark file...");
		return;
	}
	
	bookmarkDocument = [[docCont openDocumentWithContentsOfFile:bookmarkPath display:NO] retain];
	[bookmarkDocument setIsBookmarkDocument:YES];
		
	// Note, the following line is a bit of a hack, but apparently something is getting
	// screwed up with the bindings, so I either have to set display:YES in the method call above,
	// or request the window explicitly which has the same effect, otherwise it will crash
	// when trying to show the bookmark document when the user chooses the manage bookmarks menu option.
	id win = [bookmarkDocument window];

	if (nil == win) return;
	
	// To fill the menu with a list of bookmarks.
	[self refreshBookmarkMenu];
}


- (IBAction)manageBookmarks:(id)sender {
	
	if (bookmarkDocument == nil) {
		NSLog(@"bookmarkDocument is nil");
		return;
	}

	[bookmarkDocument showWindows];	
}






#pragma mark -
#pragma mark AppleScript methods

// to enable applescripting. 
// see http://developer.apple.com/cocoa/applescriptforapps.html for details.
//
// tells AppleScript which keys Terrabrowser responds to
//
/*
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key {
    if ([key isEqual:@"appleScriptDecimalLatitude"] |
		[key isEqual:@"appleScriptDecimalLongitude"] |
		[key isEqual:@"appleScriptTest"]) {
        return YES;
    } else {
        return NO;
    }
}



////////////////////////////////
// accessors for AppleScripting.
////////////////////////////////



// return the current master latitude
- (NSNumber *)appleScriptDecimalLatitude {
	Location * loc = [browserController currentMasterLocation];
    return [NSNumber numberWithDouble:[[loc latitude] doubleDegrees]];
}

- (void)setAppleScriptDecimalLatitude:(NSNumber *)num {
	Waypoint * wpt = [Waypoint waypointWithLocation:[browserController currentMasterLocation]];
	[wpt setDoubleLatitude:[num doubleValue]];
	[browserController updatePositionWithWaypoint:wpt];
}

// return the current master longitude
- (NSNumber *)appleScriptDecimalLongitude {
	Location * loc = [browserController currentMasterLocation];
    return [NSNumber numberWithDouble:[[loc longitude] doubleDegrees]];
}

- (void)setAppleScriptDecimalLongitude:(NSNumber *)num {
	Waypoint * wpt = [Waypoint waypointWithLocation:[browserController currentMasterLocation]];
	[wpt setDoubleLongitude:[num doubleValue]];
	[browserController updatePositionWithWaypoint:wpt];
}

*/

@end
