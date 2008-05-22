//
//  TerraserverTile.h
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  Represents one tile from the Terraserver.  Inherits from URLDataFetcher.
//  Designed to fetch a single image tile (either topo or satellite map) 
//  from the Microsoft Terraserver.
//
//  Each tile keeps track of which row and column it is located at in the overall map
//  in the MapView.
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

#import <AppKit/AppKit.h>
#import "URLDataFetcher.h"
#import "Constants.h"

#define TILEWIDTH 200
#define TILEHEIGHT 200

@class Location;

@interface TerraserverTile : URLDataFetcher {
	int row, col;   // the row and column that this tile represents
	
	int _s, _t;		// terraserver parameters (s is zoom, t is type)
	int _x, _y, _z;
	
	double tileDegWidth, tileDegHeight;

	NSPoint offset;			// pixel offset of location tile was set with compared
							// to the bottom left location.
	
	Location * location;	// location of the bottom left corner (?) of this tile
}

// width and height of a Terraserver Tile
+ (int)tileWidth;
+ (int)tileHeight;

- (id)initWithRow:(int)r column:(int)c;
- (id)init;

- (void)setRow:(int)r column:(int)c;
- (void)setMapType:(int)newType;

- (void)startImageTransfer;

- (float)metersPerPixel;

- (int)tileWidthInMeters;
- (double)tileWidthInDegrees;
- (double)tileHeightInDegrees;

- (void)setTileLocation:(Location*)newLoc zoom:(int)s andType:(int)t;
- (Location *)location;

- (void)getTerraserverParametersX:(int*)x Y:(int*)y Z:(int*)z S:(int*)s T:(int*)t;

- (NSPoint)offset;

- (int)row;
- (int)column;

@end
