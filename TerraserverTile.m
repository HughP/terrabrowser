//
//  TerraserverTile.m
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

#import "TerraserverTile.h"
#import "Location.h"
#import "TerraserverModel.h"
#import "Ellipsoid.h"
#import "LatLon.h"

@implementation TerraserverTile

+ (int)tileWidth { return TILEWIDTH; }
+ (int)tileHeight { return TILEHEIGHT;}

// designated intializer
- (id)initWithRow:(int)r column:(int)c {
	if (self = [super initWithOwner:self selector:@selector(doneLoading)]) {
		// each tile knows its position in a grid of tiles.
		row = r;
		col = c;
	}
		
	return self;
}

- (id)init {
	if (self = [super initWithOwner:self selector:@selector(doneLoading)]) {

	}
	
	return self;
}


- (void)setRow:(int)r column:(int)c {
	row = r;
	col = c;
}

// Sets the location of this tile with the 
// passed Location object and terraserver zoom level
// to Terraserver x, y, and z parameters.
// 
// Note that the passed location will be rounded to fit the closest tile
- (void)setTileLocation:(Location*)newLoc zoom:(int)s andType:(int)t {
	if (newLoc == location) return;
	
	_t = t;
	_s = s;
	
	double factor = pow(2, (s - 10)) * TILEWIDTH;
	// width and height are the same here
	
	// this rounds the location to one which we have a terraserver tile for
	// and sets the terraserver parameters to point to the bottom left hand corner
	double x = [newLoc easting] / factor;
	double y = [newLoc northing] / factor;
	
	_x = (int)floor(x);
	_y = (int)floor(y);
	
	// this x,y offset tells us how much the passed location had to be rounded by
	// in pixels.  This will be used to properly center the image on the user's screen
	offset.x = round((x - _x) * TILEWIDTH);
	offset.y = round((y - _y) * TILEHEIGHT);
	
	_z = [newLoc zoneNumber];

	[location release];		// release our old location
	
	if ((offset.x < 1) && (offset.y < 1)) {
		// if the offset is less than a pixel, then just set it with
		// the passed location
		location = [newLoc retain];
	} else {
		// now that we have rounded to the bottom left hand corner of the tile,
		// we need to go backwards and create a location object to correspond to
		// this corner.
		
		int easting = _x * factor;
		int northing = _y * factor;
		
		location = [[Location alloc] initWithNorthing:northing 
											  easting:easting
										   zoneLetter: [newLoc zoneLetter]
										   zoneNumber:_z
											ellipsoid: [newLoc ellipsoid]];
	}
	
	// calculate the width and height of this tile in degrees
	[self calculateTileDegreeWidth];
	[self calculateTileDegreeHeight];

}


- (Location *)location { return location; }

// Returns the pixel offset between the location this tile was set with
// and the actual position of its bottom left corner.
- (NSPoint)offset { return offset; }


// Should get called when a tile is finished downloding.
- (void)doneLoading {	
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOImageDoneLoading" object:self];
}


// Starts the image download for this particular tile from the web.
- (void)startImageTransfer {
	if (nil == location) { return; }
	
	//first, cancel the last transfer in case one was still running...
	[self abortTransfer];
	
	NSURL * url = [NSURL URLWithString:
	// this is the form of the URL to fetch one tile from the Terraserver
	[NSString stringWithFormat:
	    @"%@tile.ashx?t=%d&s=%d&x=%d&y=%d&z=%d",
		[[NSUserDefaults standardUserDefaults] stringForKey:@"TerraserverBaseURL"],
		_t, _s, _x, _y, _z]];

//	NSLog(@"Tile Lat=%f Lon=%f", [location latitude], [location longitude]);
//	NSLog(@"url = %@", url);

	[self startTransferWithURL:url];
}


// Returns the meters per pixel which corresponds to the current scale value (_s).
- (float)metersPerPixel {
	//if s = 10, mpp = 1
	//if s = 11, mpp = 2
	//if s = 12, mpp = 4
	//...

	return( pow(2, (_s - 10)));	//meters per pixel
}


// Returns the width of a tile in meters (should be equivalent to the height)
// corresponding to the current scale value
- (int)tileWidthInMeters {
	return (int)([self metersPerPixel] * (float)TILEWIDTH);
}


// Returns the tile width in degrees corresponding to the current scale value
// note, to avoid a bug at the edge of UTM zones, this actually returns the width
// of the tile adjacent to itself, but one tile closer to the meridian which is
// at easting = 500000.  
- (double)tileWidthInDegrees {
	return tileDegWidth;
}

- (void)calculateTileDegreeWidth {
	
	// how many meters wide is the tile?
	int meterWidth = [self tileWidthInMeters];
	// NSLog(@"meterWidth = %d", meterWidth);
	
	double n, e;
	char zl;
	int zn;
	
	// 1.  convert to UTM coordinates
	n = [location northing];
	e = [location easting];
	zl = [location zoneLetter];
	zn = [location zoneNumber];
	
	// 2. to avoid an error if we get to a zone boundary, check which 
	//    side of the meridian we're on. The meridian is at easting = 500,000.
	if (e > 500000) {
		e -= meterWidth;
	} else {
		e += meterWidth;
	}
	
	// 3.  convert this new UTM value back to lat/lon
	Location * newLoc = [[Location alloc] initWithNorthing:n easting:e zoneLetter:zl
												zoneNumber:zn ellipsoid:[location ellipsoid]];
		
	LatLon* leftLon;
	LatLon* rightLon;

	leftLon = [[newLoc longitude] retain];
	
	// 4.  add the meter width of the tile to the easting value
	//     and convert back to lat/lon
	e += meterWidth;
	
	[newLoc release];
	newLoc = [[Location alloc]  initWithNorthing:n easting:e zoneLetter:zl
							zoneNumber:zn ellipsoid:[location ellipsoid]];
	
	rightLon = [[newLoc longitude] retain];
		
	// 5.  find the difference between the leftLon and rightLon to get the width
	
	tileDegWidth = fabs([leftLon doubleDegrees] - [rightLon doubleDegrees]);
	
	[rightLon release];
	[leftLon release];
	[newLoc release];
}



// Returns the tile height in degrees corresponding to the current scale value.
- (double)tileHeightInDegrees {
	return tileDegHeight;
}

- (void)calculateTileDegreeHeight {
	
	LatLon* bottomLat;
	LatLon* topLat;
	
	//how many meters high is the tile?
	//(these tiles are SQUARE, so width = height for this case..
	int meterHeight = [self tileWidthInMeters];
	
//	Ellipsoid * ellip = [location ellipsoid];
	
	double n, e;
	char zl;
	int zn;
	
	bottomLat = [[location latitude] retain];
	
	// 1.  convert to UTM coordinates
	n = [location northing];
	e = [location easting];
	zl = [location zoneLetter];
	zn = [location zoneNumber];	
	
	// 2.  add the meter height of the tile to the northing value
	//     and convert back to lat/lon
	n += meterHeight;
	
	Location * newLoc = [[Location alloc] initWithNorthing:n easting:e zoneLetter:zl zoneNumber:zn
												 ellipsoid:[location ellipsoid]];
	
	topLat = [[newLoc latitude] retain];
	
	
	// 3.  find the difference between the bottomLat and topLat to get the width
	
	tileDegHeight = fabs([bottomLat doubleDegrees] - [topLat doubleDegrees]);
	
	[topLat release];
	[bottomLat release];
	[newLoc release];

}

- (void)setMapType:(int)newType { _t = newType; }

// returns by reference the terraserver parameters
- (void)getTerraserverParametersX:(int*)x Y:(int*)y Z:(int*)z S:(int*)s T:(int*)t {
	*x = _x;
	*y = _y;
	*z = _z;
	*s = _s;
	*t = _t;
}


- (int)row { return row; }
- (int)column { return col; }


- (void)dealloc {
	[location release];
	[super dealloc];
}

@end
