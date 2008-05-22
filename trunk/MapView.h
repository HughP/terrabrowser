//
//  MapView.h
//  Terrabrowser
//
//  Created by Ryan on Thu Nov 20 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  The map view is used in the main Terrabrowser window to
//  draw the map from the Terraserver, or wherever else (scanned
//  image, other server, etc.).  Therefore, the code here should 
//  *not* be specific to the Terraserver (or at least in the future
//  it shouldn't be).
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
#import "MapSourceProtocol.h"

// currently the mouse can be in two modes:
// DragMode drags the map view when the user clicks and drags.
// DistanceMode measures the distance between the first click and the position the
// user drags to.
typedef enum {
	DRAG_MODE		= 0,
	DISTANCE_MODE	= 1,
} MouseMode;


@class Location;
@class LocatedImage;

@interface MapView : NSView {
	LocatedImage * backImage;
	
	id <MapSourceProtocol> mapSource;	// the model which fetches the maps
	
	MouseMode currentMouseMode;		// current mode of the mouse.
	
	// bounds of this view in UTM coordinates
	Location * bottomLeftLocation;
	Location * topRightLocation;
	double eastingWidth, northingHeight;
	double eastingPerPixel, northingPerPixel;

	int canvasWidth, canvasHeight, metersPerPixel;
	
	BOOL perPixelSet; 
	
	// for dragging the image
	NSPoint startPoint, endPoint;
	NSPoint drawPoint;
	
	// parameters which affect the drawing of additional map elements
	// such as colors, widths, etc.
	BOOL shouldDrawFocusRing, shouldDrawWaypoints, shouldDrawWaypointLabels;
	BOOL shouldDrawTracklogs, shouldDrawRoutes, shouldDrawPositionMarker, shouldDrawScaleBar;
	BOOL justAClick;
	
	NSColor *tracklogColor, *routeColor, *gridlineColor, *scaleBarColor;
	
	int lineWidth;
	float lineTransparency;
	
	double trackQuality;
	
	BOOL shouldCalculatePaths;
	
	NSBezierPath *trackPaths, *routePaths, *gridlinePath;
}


- (void)didMoveOrResize;
- (void)setBackImage:(LocatedImage*)image;
- (void)setMapSource:(id)source;
- (Location*)locationForMousePosition;

- (void)recalculateAndRedraw;
- (void)redrawOnly;

- (NSSize)mapSize;

@end
