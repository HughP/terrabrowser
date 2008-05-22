//
//  TerraserverModel.h
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  Connects to the Microsoft Terraserver
//  http://terraserver.microsoft.com/ 
//  and fetches tiles using http (not their web service).
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Constants.h"
#import "MapSourceProtocol.h"

@class Location;
@class LocatedImage;
@class Waypoint;
@class TerraserverTile;
@class URLDataFetcher;

// Currently, there are only three map types - the URBAN_TYPE is the color one.
typedef enum {
	TOPO_TYPE	= 2,
	PHOTO_TYPE	= 1,
	URBAN_TYPE	= 4
} MapType;


@interface TerraserverModel : NSObject <MapSourceProtocol> {
	int rows, cols;
	NSSize viewSize;	// actual size of the view that is being displayed in
						// may be smaller than the size based on the rows and columns
	
	int tileWidth, tileHeight;
	
	NSMutableArray * tiles;
	
	NSImage * tileBuffer;	// buffer to store the downloaded images
	NSSize offset;			// offset into tileBuffer where real image starts
	
	LocatedImage * locatedImage;	 // cropped image with location data we'll return

	int numTilesRemaining;	// to keep track of how many tiles are done downloading

	TerraserverTile * centerTile;
	
	URLDataFetcher * datePlaceFetcher;
	
	int terraZoom;				// terraserver zoom number
	float metersPerPixel;
	
	MapType type;
	Location * location;		// the master location (near the center)
	
	NSString * _date;
	NSString * _placeName;
}

- (id)initWithSize:(NSSize)newSize 
		  location:(Location*)newLoc 
			  zoom:(int)newZoom 
		   andType:(int)newType;

+ (void)convertLocation:(Location*)loc TSParameterS:(int)s
	 toTerraserverParametersX:(int*)x Y:(int*)y Z:(int*)z;

- (void)setSize:(NSSize)newSize 
	   location:(Location*)newLoc 
		   zoom:(int)newZoom 
		andType:(int)newType;

- (void)moveLocationInDirection:(DirectionType)direction;

- (bool)modelSupportsZoom;

- (int)zoom;
- (int)maximumAllowableZoomLevel;
- (void)setZoomInMetersPerPixel:(float)newZoom;
- (float)metersPerPixel;

- (void)setMapType:(int)newType;

- (NSSize)mapSize;

- (NSURL*)centerTerraserverURL;
- (LocatedImage*)image;

- (void)zoomIn;
- (void)zoomOut;

- (Location *)location;

- (TerraserverTile*)tileAtRow:(int)r column:(int)c;

- (void)mapBoundsBottomLeft:(Location**)bL topRight:(Location**)tR;

- (void)requestNameDate;
- (NSString*)date;
- (NSString*)placeName;

- (float)percentDone;

- (int)numRows;
- (int)numColumns;

- (void)startImageTransfer;
- (void)abort;

- (void)clearTileBuffer;

@end
