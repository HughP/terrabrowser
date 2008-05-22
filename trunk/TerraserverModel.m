//
//  TerraserverModel.m
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

#import "TerraserverModel.h"
#import "TerraserverTile.h"
#import "Location.h"
#import "LocatedImage.h"
#import "Ellipsoid.h"
#import "URLDataFetcher.h"
#import "LatLon.h"


// maximum and minimum zoom levels.
static const int MAX_URBAN_ZOOM = 8;
static const int MAX_PHOTO_ZOOM = 10;
static const int MAX_TOPO_ZOOM = 11;

static const int MINZOOM = 19;


@implementation TerraserverModel

// Designated Initializer
//
// Pass this the size of the requested image, the center point location,
// the zoom level, and the map type to fetch.
//
// Note that the size doesn't have to be the same as the screen size - it 
// could be much larger if the user wants more room to scroll before having to
// load the image again.
- (id)initWithSize:(NSSize)newSize 
		  location:(Location*)newLoc 
			  zoom:(int)newZoom 
		   andType:(int)newType {
	
//	NSLog(@"initWithSize:location:zoom:andType");
	
	if (self = [super init]) {
		
		tileWidth = [TerraserverTile tileWidth];
		tileHeight = [TerraserverTile tileHeight];
		
		[self setSize:newSize 
			 location:newLoc 
				 zoom:newZoom
			  andType:newType];

		
		//Now, we'll add ourself as an observer for the tiledone message
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		
		[nc  addObserver: self
				selector: @selector(tileDoneLoading:)
					name: @"MOOImageDoneLoading"
				  object: nil];
	}
	
	return self;
}


//converts a passed Location object and Terraserver s parameter (zoom level)
//to Terraserver x, y, and z parameters.
+ (void)convertLocation:(Location*)loc TSParameterS:(int)s
	 toTerraserverParametersX:(int*)x Y:(int*)y Z:(int*)z {
	
	double factor = (pow(2, (s - 10)) * tileWidth);
	
	* x = (int)floor([loc easting] / factor);
	* y = (int)floor([loc northing] / factor);
	* z = [loc zoneNumber];	
}


// the order with which these are set is important
- (void)setSize:(NSSize)newSize 
	   location:(Location*)newLoc 
		   zoom:(int)newZoom 
		andType:(int)newType {

	[self internalSetLocation:newLoc];
	
	// we should only call setLocation directly if the zoom level hasn't 
	// changed, otherwise, the setZoom method will call it for us.
	BOOL shouldSetLocation = (terraZoom == newZoom);
	// note that shouldSetLocation must be set before we call setZoom.
	
	[self setSize:newSize];
	[self setZoom:newZoom];
	[self setMapType:newType];
	
	if (shouldSetLocation) [self setLocation:newLoc];
}

// Sets a new size for the model in terms of pixels
// and creates the two dimensional tile buffer array.
- (void)setSize:(NSSize)newSize {
	
	// don't bother doing this if the size hasn't changed.
	if ((newSize.height == viewSize.height) && (newSize.width == viewSize.width)) return;
	
	NSLog(@"Creating new tile buffer (slow).");
	
	datePlaceFetcher = nil;
	
	viewSize = newSize;

	// number of rows and columns of tiles with an extra couple on each side.
	rows = floor(viewSize.height / tileHeight) + 3;
	cols = floor(viewSize.width / tileWidth) + 2;

	// now we need to create the tile image buffer.
	// this is where the images will be drawn as they are fetched
	NSSize imagesize;
	imagesize.width = tileWidth * cols;
	imagesize.height = tileHeight * rows;

	[tileBuffer release];
	tileBuffer = [[NSImage alloc] initWithSize:imagesize];
	
	// note, Cocoa doesn't support multi-dimensional arrays, so we'll
	// have to do it by hand.  We *could* use a regular C array, but 
	// then we loose out on all the nice Cocoa array handling methods.
	
	[tiles release];  //get rid of the old tiles array first
	tiles = [[NSMutableArray arrayWithCapacity: rows] retain];	
	
	NSMutableArray * rowArray;
	TerraserverTile * t;
	
	// allocate a Tile object to each element in the 2D array
	// we'll set the locations for them later.
	
	// Visualize this 2D array with the origin in the bottom left corner
	// rows increase going up and cols increase going to the right.
	
	// r,c
	//
	// 1,0  1,1
	// 0,0  0,1
	//
	
	int r,c;
	for (r = 0; r < rows; r++) {
		//create a new row array (this is autoreleased)
		rowArray = [NSMutableArray arrayWithCapacity: cols];
		
		//fill the row array
		for (c = 0; c < cols; c++) {
			t = [[TerraserverTile alloc] initWithRow:r column:c];
			[rowArray insertObject:t atIndex: c];
			
			[t release];
			t = nil;
		}
		
		//insert the row into the tiles array.
		[tiles insertObject:rowArray atIndex:r];
	}
}

- (void)internalSetLocation:(Location*)newCenter {
	if (location != newCenter) {
		[location release];
		location = [newCenter retain];		
	}
}

// sets a new center location for the model
// setSize must have been called before calling setLocation
// which will always have happened if the designated initializer is used.
- (void)setLocation:(Location *)newCenter {
	
	// if the new location is within 1 meter of the old one, don't bother 
	// because it will look the same on the map.
//	if (nil != location) {
//		if ([location isValid] && ([location metricDistanceBetween:newCenter] < 0.001)) return;
//	}

	
	[self internalSetLocation:newCenter];
	
	// coordinates of center pixel on view
	int centerX = round(viewSize.width / 2);
	int centerY = round(viewSize.height / 2);
		
	// figure out the center tile and the offset
	[centerTile release];
	centerTile = [[TerraserverTile alloc] init];
	[centerTile setTileLocation:location zoom:terraZoom andType:type];
	
	// This offset is the number of pixels from the bottom left corner
	// of the center tile to the position the user has set as the "center".
	NSPoint tileOffset = [centerTile offset];
	
	int centerRow = ceil(centerY / tileHeight) + 1;
	int centerCol = ceil(centerX / tileWidth) + 1;
	
	int tempW = (centerCol * tileWidth) + tileOffset.x;
	int tempH = (centerRow * tileHeight) + tileOffset.y;
	offset.width = centerX - tempW;
	offset.height = centerY - tempH;
	
	// so it knows its position in the array.
	[centerTile setRow:centerRow column:centerCol];
	
	// set the center tile in the array to be our pre-initialized center tile
	[self setTile:centerTile 
			atRow:centerRow 
		   column:centerCol];
}

- (Location *)location { return location; }


#pragma mark -
#pragma mark Zooming

- (bool)modelSupportsZoom { return YES; }

- (void)setZoom:(int)newZoom {
	if (terraZoom == newZoom) return;
	
	if ((newZoom >= [self maximumAllowableZoomLevel]) && (newZoom <= MINZOOM)) {		
		
//		NSLog(@"zoom level changed");
		
		terraZoom = newZoom;
		metersPerPixel = pow(2, (terraZoom - 10));
		
		// need to reset this since the centering caluclations are based
		// on the correct zoom level
		[self setLocation:location];
	}
}

- (int)zoom { return terraZoom; }

- (void)setZoomInMetersPerPixel:(float)newZoom {
	// terraserver zoom level is 10 + log base 2 of (meters per pixel)
	terraZoom = (int)round(10 + log2(newZoom));
	metersPerPixel = newZoom;
}

// returns how many meters per pixel based on the current zoom setting.
- (float)metersPerPixel { return metersPerPixel; }

- (void)zoomIn {  // decreases number of meters per pixel
	int temp = terraZoom;
	if (temp-- >= [self maximumAllowableZoomLevel]) {
		[self setZoom:temp];
	}
}

- (void)zoomOut {  // increases number of meters per pixel
	int temp = terraZoom;
	if (temp++ <= MINZOOM) {
		[self setZoom:temp];
	}	
}

// Returns the maximum (closest) allowable zoom level for 
// the currently selected map type.
- (int)maximumAllowableZoomLevel {
	switch (type) {
		case URBAN_TYPE:
			return MAX_URBAN_ZOOM;
			break;
		case TOPO_TYPE:
			return MAX_TOPO_ZOOM;
			break;
		case PHOTO_TYPE:
			return MAX_PHOTO_ZOOM;
			break;
	}

	return MAX_PHOTO_ZOOM;
}

#pragma mark -
#pragma mark Assorted methods

// satellite, topo, or urban (color)
- (void)setMapType:(int)newType {	type = newType; }


// abort the transfer
- (void)abort {
	int r,c;
	id arrayrow;
	
	[datePlaceFetcher abortTransfer];
	
	for (r = 0; r < rows; r++) {
		arrayrow = [tiles objectAtIndex:r];
		
		for (c = 0; c < cols; c++) {
			[[arrayrow objectAtIndex:c] abortTransfer];
		}
	}
}

// Returns the tile at the given (row, column);
// for speed, this DOES NOT DO ANY BOUNDS CHECKING!!  Be careful!
- (TerraserverTile*)tileAtRow:(int)r column:(int)c {
	id arrayRow = [tiles objectAtIndex:r];
	if (arrayRow != nil) {
		return [arrayRow objectAtIndex:c];		
	}

	return nil;
}

// ** again, no bounds checking, so be careful **
- (void)setTile:(TerraserverTile*)tile atRow:(int)r column:(int)c {
	id arrayRow = [tiles objectAtIndex:r];
	if (arrayRow != nil) {
		[arrayRow replaceObjectAtIndex:c withObject:tile];
	}
	return;
}


// Returns an image along with location bounds for the image
// (bottom left and top right)
// 
// crops and centers the tileBuffer
- (LocatedImage*)image {

	if (nil == locatedImage) {
		locatedImage = [[LocatedImage alloc] init];
	}
	
	// this is the image we'll return
	NSImage * croppedImage = [locatedImage image];  
		
	if ((nil == croppedImage) ||
		([croppedImage size].width != viewSize.width) || 
		([croppedImage size].height != viewSize.height)) {
		// only re-allocate if the size has changed
		croppedImage = [[NSImage alloc] initWithSize:viewSize];
	}
	
	[croppedImage lockFocus];
	
	NSRect sourceRect, destRect;
	
	sourceRect.size = viewSize;
	sourceRect.origin.x = -offset.width;
	sourceRect.origin.y = -offset.height;

	destRect.size = viewSize;
	destRect.origin.x = 0;
	destRect.origin.y = 0;
	
	[tileBuffer drawInRect:destRect fromRect:sourceRect
		 operation:NSCompositeCopy fraction:1.0];
	
	[croppedImage unlockFocus];
	
	// now we need to set the bounds properly
	// for the top right and bottom left
	
	Location *bL, *tR;	
	[self mapBoundsBottomLeft:&bL topRight:&tR];
	[locatedImage setBottomLeft:bL topRight:tR];
	[locatedImage setImage:croppedImage];
	
	return locatedImage;
}


// assigns a location to each tile and then asks each tile to 
// fetch an image from the Terraserver.
- (void)startImageTransfer {
	
	// how many tiles are left to load?
	numTilesRemaining = rows * cols;
	
	// r,c
	//
	// 1,0  1,1
	// 0,0  0,1
	//
	
	int r, c;
	id arrayrow;
	TerraserverTile * tile;
	
	Ellipsoid * ellipsoid = [location ellipsoid];
		
	[self clearTileBuffer];
	
	// First, figure out where the center tile is (what row and col number)
	int centerRow = [centerTile row];
	int centerCol = [centerTile column];
		
	int xLeft, yBottom, z, t, s;
	
	[centerTile getTerraserverParametersX:&xLeft Y:&yBottom Z:&z 
										S:&s T:&t];
	t = type;
	
//	NSLog(@"centerRow: %d, centerCol:%d", centerRow, centerCol);
//	NSLog(@"x:%d, y:%d, z:%d", x, y, z);
	
	// Start out in the bottom left corner, so we subtract the center point...
	xLeft -= centerCol;
	yBottom -= centerRow; 
	
	int x, y;
	double factor;
	factor = pow(2, (s - 10));
	factor = floor(factor * tileHeight);
	
	double northing, easting;
	Location * loc;
	
	for (r = 0; r < rows; r++) {
		arrayrow = [tiles objectAtIndex:r];
		
		y = yBottom + r;
		northing = y * factor;
		
		for (c = 0; c < cols; c++) {
			x = xLeft + c;
			
			easting = x * factor;
			
			loc = [[Location alloc] initWithNorthing:northing easting:easting
					zoneLetter:[location zoneLetter]
				zoneNumber:z ellipsoid:ellipsoid];
			
//			[loc fixZoneNumber];	//a **HACK** to fix zone numbers on the boundary
			//apparently this *** fix zone number *** doesn't work right?!?
			
			tile = [arrayrow objectAtIndex:c];
			
			[tile setTileLocation:loc zoom:s andType:t];
					
			//NSLog(@"degWidth = %f", [tile tileWidthInDegrees]);
			//NSLog(@"tileLon = %f, zoneNum = %d", [[tile location] longitude], [[tile location] zoneNumber]);
		 
			[tile startImageTransfer];
			[loc release];
		}
	}

	[self requestNameDate];
	
}


// Attempts to download the HTML file from Terraserver asynchronously.  The method
// called parseNameDate will be called by the URLDataFetcher when the download is complete.
//
// This *should* be getting the date/location from the tile of the current master location
// (ie, where the location marker sits).
- (void)requestNameDate {
		
	NSURL * url = [self centerTerraserverURL];

		
	if (nil == datePlaceFetcher) {  //then allocate it..
		datePlaceFetcher = [[URLDataFetcher alloc] 
					initWithOwner:self selector:@selector(parseNameDate)];
		
	}
	
	[datePlaceFetcher startTransferWithURL:url];
	//when it's done, it will call parseNameDate to parse the data
}

// returns the URL which points to the center terraserver tile.
- (NSURL*)centerTerraserverURL {
	int x, y, z, t, s;
	
	t = type;  //topo, satellite map, or urban area (color)
	s = terraZoom;  //zoom level
	
	[centerTile getTerraserverParametersX:&x Y:&y Z:&z S:&s T:&t];
	
	NSURL * url = [NSURL URLWithString:
		[NSString stringWithFormat:
			@"%@image.aspx?t=%d&s=%d&x=%d&y=%d&z=%d&w=1",
			[[NSUserDefaults standardUserDefaults] stringForKey:@"TerraserverBaseURL"],
			t, s, x, y, z]];
	
	return url;
}


// Called by the datePlaceFetcher when it's done asynchronously downloading
// the HTML file to parse for the name and date.  If the HTML code on the Terraserver 
// site changes too much, this method will break.
- (void)parseNameDate {

	NSLog(@"parseNameDate");
	
	[_date release];
	[_placeName release];
	_date = [[NSString stringWithString:@"Error"] retain];
	_placeName = [[NSString stringWithString:@"Error"] retain];
	
	NSString * html = [datePlaceFetcher string];
	if (nil == html) return;
	
	int len = [html length];	
	if (len <= 0) return;
	
	BOOL b;
	int newPos;
	
	//http://terraserver-usa.com/image.aspx?T=1&S=14&X=161&Y=1111&Z=12&W=1
	//<span id="PlaceTitle" class="plnme">18 km SE of Tucson, Arizona, United States</span>
	//<span id="PrintDate" class="pldte">16 May 1992</span>
			
	NSScanner * scanner = [NSScanner scannerWithString:html];
	[scanner setCaseSensitive:NO];
	
	//try to parse out the date.
	b = [scanner scanUpToString:@"PrintDate" intoString:nil];
	b = [scanner scanUpToString:@">" intoString:nil];
	
	newPos = [scanner scanLocation] + 1;
	if (newPos >= len) return;
	[scanner setScanLocation: newPos];
	
	[_date release];
	b = [scanner scanUpToString:@"</span>" intoString:&_date];
	[_date retain];
	
	//NSLog(@"date = %@", _date);
	
	[scanner setScanLocation:0];
	[scanner scanUpToString:@"PlaceTitle" intoString:nil];
	b = [scanner scanUpToString:@">" intoString:nil];
	
	newPos = [scanner scanLocation] + 1;
	if (newPos >= len) return;

	[scanner setScanLocation: newPos];
	[_placeName release];
	b = [scanner scanUpToString:@"</span>" intoString:&_placeName];
	[_placeName retain];

	//NSLog(@"place = %@", _placeName);
		
	//send a notification now that we have the date and place
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOPlaceAndDateDownloaded" object:self];	
}


- (NSString*)date {
	return _date;
}

- (NSString*)placeName {
	return _placeName;
}

- (void)moveLocationInDirection:(DirectionType)direction {	
	NSLog(@"moveLocationInDirection called");
	double degWidth, degHeight;
	
	degWidth = [[self tileAtRow:0 column:0] tileWidthInDegrees];
	degHeight = [[self tileAtRow:0 column:0] tileHeightInDegrees];

	Ellipsoid * ellip = [location ellipsoid];
	LatLon * lat = [[location latitude] copyWithZone:nil];
	LatLon * lon = [[location longitude] copyWithZone:nil];
	
	switch (direction) {
		case NORTH:
			[lat offsetWithDouble:degHeight];
			break;
		case SOUTH:
			[lat offsetWithDouble: (-degHeight)];
			break;
		case EAST:
			[lon offsetWithDouble:degWidth];
			break;
		case WEST:
			[lon offsetWithDouble: (-degWidth)];
			break;
	}


	Location * newLoc = [[Location alloc]   initWithLatitude:lat 
											longitude:lon 
											ellipsoid:ellip];
	
	[self setLocation: newLoc];
	
	[lat release];
	[lon release];
	[newLoc release];
	
	NSLog(@"Terraserver model done moving");
}


//clears the tile buffer...
- (void)clearTileBuffer {
	[tileBuffer lockFocus];	
	
	NSRect r;
	r.size.width = [tileBuffer size].width;
	r.size.height = [tileBuffer size].height;
	r.origin.x = 0;
	r.origin.y = 0;
	
	//fill the rect with a background color
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:r];
		
	[tileBuffer unlockFocus];
}

- (NSSize)mapSize {
	return viewSize;
}


// Returns by reference the bottom left and top right locations for the map.
- (void)mapBoundsBottomLeft:(Location**)bL topRight:(Location**)tR {
	
	// we start out with the center location
	Location * center = location;
	
	// figure out the width and height of the view area in degrees	
	// we'll estimate based on the center tile.
	double tileDegWidth = [centerTile tileWidthInDegrees];
	double tileDegHeight = [centerTile tileHeightInDegrees];

	// half the width and height of the entire view area in degrees
	double halfDegWidth = (tileDegWidth * (viewSize.width / tileWidth )) / 2.0;
	double halfDegHeight = (tileDegHeight * (viewSize.height / tileHeight )) / 2.0;
	
	// figure out the top right corner first
	LatLon *newLon, *newLat;
	newLat = [[center latitude] copyWithZone:nil];
	[newLat offsetWithDouble: halfDegHeight];
	
	newLon = [[center longitude] copyWithZone: nil];
	[newLon offsetWithDouble: halfDegWidth];
		
	*tR = [[[Location alloc] initWithLatitude:newLat
									longitude:newLon
									ellipsoid:[center ellipsoid]] autorelease];

	[newLat release];	[newLon release];

	// now, figure out the bottom left location
	newLat = [[center latitude] copyWithZone:nil];
	[newLat offsetWithDouble: -halfDegHeight];
	
	newLon = [[center longitude] copyWithZone: nil];
	[newLon offsetWithDouble: -halfDegWidth];

	
	*bL = [[[Location alloc] initWithLatitude:newLat
									longitude:newLon
									ellipsoid:[center ellipsoid]] autorelease];
	
	[newLat release];	[newLon release];		
}

#pragma mark -
#pragma mark Accessors

// returns the percent done downloading
- (float)percentDone {
	float numTiles = rows * cols;
	
	if (numTilesRemaining <= 0) return 100;
	
	return 100.0 * (numTiles - numTilesRemaining) / (float)numTilesRemaining;
}

- (int)numRows { return rows; }
- (int)numColumns { return cols; }


#pragma mark -
#pragma mark Notifications

// This is called by each tile as it finishes loading.  The tile will pass
// itself as the argument so we will be able to grab the picture out of it.
- (void)tileDoneLoading:(NSNotification *)note {
	
	TerraserverTile * t = [note object];
	
//	NSLog(@"Tile done loading, row = %d, col = %d", [t row], [t column]);

	// draw the tile into the image buffer
	[tileBuffer lockFocus];
	
	NSRect sourceRect, destRect;

	NSImage*  ti = [t image];
	
	sourceRect.size = [ti size];
	sourceRect.origin.x = 0;
	sourceRect.origin.y = 0;
	
	destRect.size.height = tileHeight;
	destRect.size.width = tileWidth;
	destRect.origin.x = [t column] * tileWidth;
	destRect.origin.y = [t row] * tileHeight;

	//actually draw the tile into the tilebuffer
//	NSLog(@"width = %f", [[t image] size].width);
	

//	NSSize newSize;
//	newSize.width = TILEWIDTH;
//	newSize.height = TILEHEIGHT;
//	[ti setSize:newSize];

	[ti drawInRect:destRect fromRect:sourceRect
					operation:NSCompositeCopy fraction:1.0];
		
	[tileBuffer unlockFocus];
		

	//send a notification with the newly updated image and bounds
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOMapDownloadProgress" object:[self image]];	
	
	numTilesRemaining--;
	
	if (numTilesRemaining == 0) {	// then we're done downloading.
		[nc postNotificationName:@"MOOMapDownloadFinished" object:[self image]];
	}
}



- (void)dealloc {
	//remove this object as an observer in the NotificationCenter
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: self];

	[tiles release];
	[tileBuffer release];
	[location release];
	[datePlaceFetcher release];
	[locatedImage release];
	
	[_date release];
	[_placeName release];
	
	[super dealloc];
}

@end
