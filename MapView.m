//
//  MapView.m
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


#import "MapView.h"
#import "Constants.h"
#import "Waypoint.h"
#import "Location.h"
#import "AppController.h"   
#import "DistanceFormatter.h"
#import "LatLon.h"
#import "TerraserverModel.h"
#import "XMLElement.h"

@implementation MapView

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {

		justAClick = YES;
		
		// start off in drag mode by default (which drags the map as the user clicks and drags).
		currentMouseMode = DRAG_MODE;
		
		drawPoint.x = 0;
		drawPoint.y = 0;
		
		shouldCalculatePaths = YES;
		perPixelSet = NO;
		
		scaleBarColor = [[NSColor whiteColor] retain];
		
		trackQuality = 1;
		
		[self updateFromPrefs];
		
		//Now, we'll add ourself as an observer for the redraw message
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];

		[nc  addObserver: self
				selector: @selector(redrawMap:)
					name: @"MOODoRedrawMapView"
				  object: nil];
		
		[nc  addObserver: self
				selector: @selector(updateMapView:)
					name: @"MOODoRefreshMapView"
				object: nil];
		
		[nc  addObserver: self
				selector: @selector(userPrefsUpdated:)
					name: @"MOOUserPrefsUpdated"
				  object: nil];

		[self setFocusRingType:NSFocusRingTypeExterior];

    }
    return self;
}


// Called when a change is made to the preferences which specify how the map should be 
// drawn.  Normally, a reload of the image would not be required for this, so skip it.
- (void)updateFromPrefs {
	shouldDrawWaypoints = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowWaypoints"];
	shouldDrawWaypointLabels = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowWaypointLabels"];
	shouldDrawTracklogs = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowTracklogs"];
	shouldDrawRoutes = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowRoutes"];
	shouldDrawPositionMarker = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowPositionMarker"];
	shouldDrawScaleBar = [[NSUserDefaults standardUserDefaults] boolForKey:@"BrowserShowScaleBar"];
	
	lineWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"BrowserLineWidth"];
	lineTransparency = [[NSUserDefaults standardUserDefaults] floatForKey:@"BrowserLineTransparency"];
	
	trackQuality = [[NSUserDefaults standardUserDefaults] floatForKey:@"BrowserPathRenderingQuality"];
	
	NSData * data;

	data = [[NSUserDefaults standardUserDefaults] dataForKey:@"BrowserScaleBarColor"];
	if (data) { scaleBarColor = [[NSUnarchiver unarchiveObjectWithData:data] retain]; }

	data = [[NSUserDefaults standardUserDefaults] dataForKey:@"BrowserRouteColor"];
	if (data) { routeColor = [[NSUnarchiver unarchiveObjectWithData:data] retain]; }
	
	data = [[NSUserDefaults standardUserDefaults] dataForKey:@"BrowserTracklogColor"];
	if (data) { tracklogColor = [[NSUnarchiver unarchiveObjectWithData:data] retain]; }
	
	data = [[NSUserDefaults standardUserDefaults] dataForKey:@"BrowserGridlineColor"];
	if (data) { gridlineColor = [[NSUnarchiver unarchiveObjectWithData:data] retain]; }
	
	shouldCalculatePaths = YES;
	
//	NSLog(@"MapView updating prefs...");
}

//called when the user updates their prefs
- (void)userPrefsUpdated:(NSNotification*)note {
	[self updateFromPrefs];		
	[self setNeedsDisplay:YES];
}


// call this if the map was moved or resized.. Basically,
// it sets a boolean which controls whether or not we should
// recalculate things like where to draw the tracklog..
- (void)didMoveOrResize {
	shouldCalculatePaths = YES;
	
	[self updateMapView:nil];
}


- (void)setMapSource:(id)source {
	if (source != mapSource) {
		[mapSource release];
		mapSource = [source retain];
	}
}

// called by the map source to set the backgroud image as well as the image bounds.
- (void)setBackImage:(LocatedImage*)image {

	if (image != backImage) {
		[backImage release];
		backImage = [image retain];
	}
	
	[bottomLeftLocation release];
	[topRightLocation release];
	
	bottomLeftLocation = [[backImage bottomLeft] retain];
	topRightLocation = [[backImage topRight] retain];
	
	// now figure out a few things which will be used to place waypoints
	// in the correct locations.
	eastingWidth = fabs([topRightLocation easting] - [bottomLeftLocation easting]);
	northingHeight = fabs([topRightLocation northing] - [bottomLeftLocation northing]);
	
	NSSize size;
	size = [[backImage image] size];
	
	northingPerPixel = northingHeight / size.height;
	eastingPerPixel = eastingWidth / size.width;
	
	if ((northingPerPixel > 0.0) && (eastingPerPixel > 0.0)) {
		perPixelSet = YES;
	}	
}

- (BOOL)acceptsFirstResponder {
	return YES; //so we can get keydown events
}


// pass it a point in view coordinates (relative to the NSView)
// and it will return the point in image coordinates (relative to the NSImage drawn in the view).
- (NSPoint)convertToImageCoordinates:(NSPoint)p {
	NSPoint newP = p;
	newP.x -= drawPoint.x;
	newP.y -= drawPoint.y;
	return newP;
}

// Returns a Location object for the current mouse position, or nil 
// if the mouse isn't in the mapview.
//
// Note - this method currently has a bug in it which will only show
// up if the user is going across a zone boundary because it sets the
// zone number to that of the bottom left hand corner.
//
- (Location*)locationForViewCoordinates:(NSPoint)vP {
	NSPoint p = [self convertToImageCoordinates: vP];
		
	double northing = (p.y * northingPerPixel) + [bottomLeftLocation northing];
	double easting = (p.x * eastingPerPixel) + [bottomLeftLocation easting];
	
	Ellipsoid * ellip = [[[Ellipsoid alloc] init] autorelease];
	
	// figure out the zone letter and zone number
	
	char zLetter = [bottomLeftLocation zoneLetter];
	int zNumber = [bottomLeftLocation zoneNumber];
	
	Location * newLoc = [[[Location alloc] initWithNorthing:northing 
													easting:easting
												 zoneLetter:zLetter zoneNumber:zNumber
												  ellipsoid:ellip] autorelease];
	
	return newLoc;
}

- (Location*)locationForMousePosition {
	NSPoint p = [[self window] mouseLocationOutsideOfEventStream];
	p = [self convertPoint:p fromView:nil];  //convert from window coordinates to view coordinates.
	
	if ((p.x < [self bounds].origin.x) || (p.x > [self bounds].size.width) ||
		(p.y < [self bounds].origin.y) || (p.y > [self bounds].size.height)) {
		return nil;
	}
	
	return [self locationForViewCoordinates:p];
}


// returns the point (x,y coordinates on the map) of the passed location object.
- (NSPoint)pointForLocation:(Location*)loc {
	// figure out where the location should be on the map.
	// note, we return if northingPerPixel or eastingPerPixel == 0, so divide
	// by zero is not possible.
	
	NSPoint p;
	
	p.x = (int)floor(([loc easting] - [bottomLeftLocation easting]) / eastingPerPixel);
	p.y = (int)floor(([loc northing] - [bottomLeftLocation northing]) / northingPerPixel);
	
	// adjust for new origin if the user moved the picture by dragging.
	p.x += drawPoint.x;
	p.y += drawPoint.y;
	
	return p;
}


#pragma mark -
#pragma mark Events

//this is so the user can navigate with the arrow keys when they click in 
//the mapView.
- (void)keyDown:(NSEvent *)theEvent {
		
	BOOL good = YES;
	
	int characterIndex;
    int charactersInEvent;
	
    charactersInEvent = [[theEvent characters] length];
    for (characterIndex = 0; characterIndex < charactersInEvent;  
		 characterIndex++) {
        if ([[theEvent characters] 
			characterAtIndex:characterIndex] == NSUpArrowFunctionKey) {
			[mapSource moveLocationInDirection:NORTH];
		} else if ([[theEvent characters] 
			characterAtIndex:characterIndex] == NSDownArrowFunctionKey) {
			[mapSource moveLocationInDirection:SOUTH];
		} else if ([[theEvent characters] 
			characterAtIndex:characterIndex] == NSLeftArrowFunctionKey) {
			[mapSource moveLocationInDirection:WEST];
		} else if ([[theEvent characters] 
			characterAtIndex:characterIndex] == NSRightArrowFunctionKey) {
			[mapSource moveLocationInDirection:EAST];
		} else {
			good = NO;
		}
    }
	
	
	if (good) {
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		
		[nc postNotificationName:@"MOOGotoWaypoint" object: [Waypoint waypointWithLocation:[mapSource location]]];
	}
}



- (void)mouseEntered:(NSEvent *)theEvent {
	NSLog(@"mouseEntered");
}

- (void)mouseDown:(NSEvent *)theEvent {

	if (NSAlternateKeyMask & [theEvent modifierFlags]) {
		currentMouseMode = DISTANCE_MODE;
	} else {
		currentMouseMode = DRAG_MODE;
	}
	
	startPoint = [theEvent locationInWindow];

	NSCursor* cursor;
	
	// We have two modes - drag mode for dragging the map, and 
	// distance mode for calculating distances.
	switch ((int)currentMouseMode) {
		case DRAG_MODE:
			// change the cursor to a closed hand.
			cursor = [NSCursor closedHandCursor];

			break;
		case DISTANCE_MODE:			
			// change the cursor to a closed hand.
			cursor = [NSCursor crosshairCursor];

			break;
	}
	
	[cursor push];
	
}


- (void)mouseDragged:(NSEvent *)theEvent {
	endPoint = [theEvent locationInWindow];

	justAClick = NO;
	
	switch ((int)currentMouseMode) {
		case DRAG_MODE:
			drawPoint.x += endPoint.x - startPoint.x;
			drawPoint.y += endPoint.y - startPoint.y;
			
			startPoint = endPoint;
			
			// note - this employs brute force by recalculating everything 
			// we should really just offset them all by the correct number of pixels.
			shouldCalculatePaths = YES;			
			
			break;
		case DISTANCE_MODE:
			break;
	}
	
	[self setNeedsDisplay:YES];
}


- (void)mouseUp:(NSEvent *)theEvent {
	NSPoint p;
	Location * newCenter;
	
	NSPoint upPoint = [theEvent locationInWindow];
	
	justAClick = ((upPoint.x == startPoint.x) && (upPoint.y == startPoint.y));
	
	if (DRAG_MODE == currentMouseMode) {
		p.x = round(canvasWidth / 2);
		p.y = round(canvasHeight / 2);
		
		newCenter = [self locationForViewCoordinates:p];
		
		[[NSNotificationCenter defaultCenter] 
		postNotificationName:@"MOOGotoWaypoint" 
					  object: [Waypoint waypointWithLocation:newCenter]];
		
		drawPoint.x = 0;
		drawPoint.y = 0;
	} else {
		//distance mode
	
	}
	
	// restore the cursor to its default.
	NSCursor * cursor = [NSCursor currentCursor];
	[cursor pop];
}



#pragma mark -
#pragma mark Notifications

// just redraws the map along with all waypoints, tracklogs, etc.
- (void)redrawMap:(NSNotification*)note {
	[self recalculateAndRedraw];
}


// if passed a nil note, then it just updates the display..
- (void)updateMapView:(NSNotification*)note {
	
	if ((nil == note) || ([note object] == nil)) {
		[self recalculateAndRedraw];
		return;
	}
		
	//the note contains the new image (and bounds) to draw in the mapview.
	[self setBackImage: (LocatedImage*)[note object]];
		
	shouldCalculatePaths = YES;
	
	[self recalculateAndRedraw];
}


#pragma mark -
#pragma mark Drawing methods


- (void)recalculateAndRedraw {
	shouldCalculatePaths = YES;
	[self setNeedsDisplay:YES];
}

- (void)redrawOnly {
	[self setNeedsDisplay:YES];
}


- (void)drawRect:(NSRect)rect {
	NSRect r;
//	NSPoint p;
//	NSBezierPath * path;
	
	r = [self frame];
	canvasWidth = r.size.width;
	canvasHeight = r.size.height;
	
	//draw the background
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:[self visibleRect]];
	
	NSSize size;
	
	if (backImage != nil) {		// draw background image
		r.origin.x = 0;
		r.origin.y = 0;	
	
		size = [[backImage image] size];
		r.size.width = size.width;
		r.size.height = size.height;
		
		[[NSColor blackColor] set];
	//	p.x = 0; p.y = 0;
		
		[[backImage image] drawAtPoint:drawPoint fromRect:r operation:NSCompositeCopy fraction:1.0];
	}
	
	if (shouldDrawTracklogs)		{ [self drawTracks]; }	
	if (shouldDrawRoutes)			{ [self drawRoutes];	}	
	if (shouldDrawWaypoints)		{ [self drawWaypoints]; }
	if (shouldDrawPositionMarker)	{ [self drawCurrentPositionMarker]; }
	if (shouldDrawScaleBar)			{ [self drawScaleBar]; }
	
	if (currentMouseMode == DISTANCE_MODE) { [self drawDistanceMeasurement]; }
	
	if (shouldDrawFocusRing) {
		NSSetFocusRingStyle(NSFocusRingAbove); 
		[[NSColor keyboardFocusIndicatorColor] set]; 
		NSFrameRect([self visibleRect]);
	} else {
		[self setKeyboardFocusRingNeedsDisplayInRect: [self visibleRect]];
	}

	metersPerPixel = [mapSource metersPerPixel];
	
	// so we don't recalculate things too often
	shouldCalculatePaths = NO;

}



// Pass this an array of waypoints to draw and it will draw them
// all connected together (ie, for a tracklog or route).
- (NSBezierPath*)drawLinkedArrayOfWaypoints:(NSArray*)waypoints {
	if (!waypoints) return nil;
	if (!perPixelSet) return nil;	
	if ([waypoints count] < 1) return nil;
	
	// we'll draw the array of waypoints in this path.
	NSBezierPath * path = [NSBezierPath bezierPath];
	
	NSEnumerator * wptEnumerator = [waypoints objectEnumerator];
	id wptObj;
	Waypoint * wpt;
	
	NSPoint currentPoint, lastPoint;
	
	// First, perform an initial loop through the waypoints and make sure that at 
	// least one of them is currently visible.  If they're all invisible, then 
	// don't draw the track.
	
	BOOL shouldDraw = NO;
	float fudge = 0.05;  // fudge factor in case the calculation about the corners
	// of the screen isn't quite right.
	double blLat = [bottomLeftLocation doubleLatitude] - fudge;
	double blLon = [bottomLeftLocation doubleLongitude] - fudge;
	double trLat = [topRightLocation doubleLatitude] + fudge; 
	double trLon = [topRightLocation doubleLongitude] + fudge;
	
	while (wptObj = [wptEnumerator nextObject]) {
		wpt = (Waypoint*)wptObj;
		
		if (!(	([wpt doubleLatitude]  < blLat) ||
				([wpt doubleLatitude]  > trLat) ||
				([wpt doubleLongitude] < blLon) ||
				([wpt doubleLongitude] > trLon) ) ) {
			shouldDraw = YES;
			break;
		}
	}	
	
	// If we didn't find any points which are visible, then return.
	if (!shouldDraw) return nil;
		
	NSLog(@"calculating track or route");
		
	// smaller is higher quality
	// the user sets trackQuality from a slider in the preferences.  We should
	// also increase the quality automatically as we zoom in.
	// Zoomed all the way in is 8, all the way out is 19.
	
	float pixelThreshold = 25.0 - trackQuality;   // trackQuality goes from 0 to 25
	
	int count = 0;
	int numDrawn = 0;

	wpt = [waypoints objectAtIndex:0];
	
	lastPoint = [self pointForLocation:[wpt location]];
	
	float dx, dy;
	const outsideClippingWidth = 5;  // how many pixels outside the frame to draw
	
	
	//loop through each trackpoint in this track segment
	while (wptObj = [wptEnumerator nextObject]) {
		wpt = (Waypoint*)wptObj;		
	
		currentPoint = [self pointForLocation:[wpt location]];
		
		dx = abs(currentPoint.x - lastPoint.x);
		dy = abs(currentPoint.y - lastPoint.y);
				
		// only draw the new point if it is outside of the x and y thresholds (ie, more
		// than that many pixels away), or if the pixelThreshold is set to 0 (maximum quality)
		if ( ((dx >= pixelThreshold) || (dy >= pixelThreshold))) {

			// then add it to the path
			[path moveToPoint: lastPoint];
			[path lineToPoint: currentPoint];
			
			numDrawn++;
		
			lastPoint = currentPoint;
		}

		count++;
	}
	
	//NSLog(@"drew %d track points out of %d total.", numDrawn, count);
	
	return path;	
}



// Draw track points.
- (void)drawTracks {
	
	[[tracklogColor colorWithAlphaComponent:lineTransparency] set];
	
	if ((!shouldCalculatePaths) && (trackPaths)) {
		//just draw the track paths
		NSLog(@"drawing old track path");
		[trackPaths stroke];
		return;
	}
	
	//if we make it to here, then we need to calculate the track paths.
	
	[trackPaths release];
	trackPaths = [[NSBezierPath bezierPath] retain];
	[trackPaths setLineWidth:lineWidth];
	
	NSArray *tracks, *track, *trackSeg;
	
	NSEnumerator *waypointDocEnumerator = [[AppController globalFileList] objectEnumerator];
	NSEnumerator *trackEnumerator, *trackSegEnumerator;
	
	id waypointDoc;
	
	//loop through each GPX file's tracks
	while ((waypointDoc = [waypointDocEnumerator nextObject])) {
		
		tracks = [waypointDoc tracks];

		//loop through each track log
		trackEnumerator = [tracks objectEnumerator];
		while (track = [trackEnumerator nextObject]) {
			
			if ([track includeInList]) {		// should we draw *this* track?
			
				//loop through each track segment
				trackSegEnumerator = [track objectEnumerator];
				while (trackSeg = [trackSegEnumerator nextObject]) {
			
					NSBezierPath * path = [self drawLinkedArrayOfWaypoints: [trackSeg list]];
					if (path != nil) {

						[trackPaths appendBezierPath: path];	
					}	
				}
			}
		}
	}
	
	// actually draw the points
	[trackPaths stroke];
}


- (void)drawRoutes {
	
	[[routeColor colorWithAlphaComponent:lineTransparency] set];
	
	if ((!shouldCalculatePaths) && (routePaths)) {
		//just draw the route paths
		NSLog(@"drawing old route path");
		[routePaths stroke];
		return;
	}
	
	//if we make it to here, then we need to calculate the route paths.
	
	[routePaths release];
	routePaths = [[NSBezierPath bezierPath] retain];
	[routePaths setLineWidth:lineWidth];

	NSArray *routes, *route;
	
	NSEnumerator *waypointDocEnumerator = [[AppController globalFileList] objectEnumerator];
	NSEnumerator *routeEnumerator;
	
	id waypointDoc;
	
	//loop through each GPX file's routes
	while ((waypointDoc = [waypointDocEnumerator nextObject])) {
		
		routes = [waypointDoc routes];
		
		//loop through each route
		routeEnumerator = [routes objectEnumerator];
		while (route = [routeEnumerator nextObject]) {

			if ([route includeInList]) {		// should we draw *this* route?
				NSBezierPath * path = [self drawLinkedArrayOfWaypoints:[route list]];
				[routePaths appendBezierPath: path];
			}
		}
	}
	
	// actually draw the points
	[routePaths stroke];
}



//draw the waypoints which are stored in the global variable accessed
//from the AppController.
- (void)drawWaypoints {
	
	if (! perPixelSet) return;
	
	NSArray * list;
	Waypoint * wpt;
	
	NSEnumerator *dictEnumerator = [[AppController globalFileList] objectEnumerator];
	NSEnumerator *wptEnumerator;
	id value, wptObj;

	//NSLog(@"dictionary has %d items", [[AppController globalFileList] count]);
	
	int x, y;
    NSPoint p;
	NSPoint wptPt;
	NSRect r, r2;
	NSImage * img;
	
	const int ICONSIZE = 13;
	int ISO2 = floor(ICONSIZE / 2);
	
	float bl_lat = [[bottomLeftLocation latitude] doubleDegrees];
	float bl_lon = [[bottomLeftLocation longitude] doubleDegrees];
	float tr_lat = [[topRightLocation latitude] doubleDegrees];
	float tr_lon = [[topRightLocation longitude] doubleDegrees];
					
	// loop through each waypointDocument object which is 
	// stored in the globalFileList	
	
	while ((value = [dictEnumerator nextObject])) {
		list = [value waypointArray];
		
		wptEnumerator = [list objectEnumerator];
		
		//loop through each waypoint
		while (wptObj = [wptEnumerator nextObject]) {
			wpt = (Waypoint*)wptObj;
			//NSLog(@"%@\n\n", wpt);
			//NSLog(@"lon:%f", [wpt longitude]);
			
			//figure out where the waypoint should be on the map.
			wptPt = [self pointForLocation:[wpt location]];
			x = wptPt.x;
			y = wptPt.y;
			
			float wpt_lat = [wpt doubleLatitude];
			float wpt_lon = [wpt doubleLongitude];
			
			if ((x < 0) || (x > canvasWidth) ||
				(y < 0) || (y > canvasHeight) ||
				(wpt_lat > tr_lat) || (wpt_lat < bl_lat) ||
				(wpt_lon > tr_lon) || (wpt_lon < bl_lon) ) {
				continue;
			}
			//NSLog(@"WPTx,y = (%d, %d)", x, y);
			//NSLog(@"WPLLat,Lon = (%f, %f)", [[wpt longitude] doubleDegrees], [[wpt latitude] doubleDegrees]);
			//	  [[bottomLeftLocation latitude] doubleDegrees] );
			//NSLog(@"bLEasting = %f , bLNorthing = %f", [bottomLeftLocation easting], 
			//	  [bottomLeftLocation northing]);

			
			// The rectangle to draw the icon into.
			r.origin.x = x - ISO2;
			r.origin.y = y - ISO2;
			r.size.width = ICONSIZE;
			r.size.height = ICONSIZE;
			
			NSBezierPath* labelBackdrop;
			if (shouldDrawWaypointLabels) {
				// First, draw the background rectangle	for the waypoint label 
				// but only if we're supposed to draw it.
				r2.size = [[wpt name] sizeWithAttributes:nil];
				r2.size.width += 5;
				r2.size.height = ICONSIZE;
				r2.origin = r.origin;
				r2.origin.x += ICONSIZE;
				
				[[[NSColor whiteColor] colorWithAlphaComponent:lineTransparency] set];
				labelBackdrop = [NSBezierPath bezierPathWithRect:r2];
				[labelBackdrop setLineJoinStyle:NSRoundLineJoinStyle];
				[labelBackdrop fill];
			}
			
			// Next, draw the waypoint icon.
			if (img = [wpt image]) {
				r2.origin.x = 0;
				r2.origin.y = 0;
				r2.size.width = ICONSIZE;
				r2.size.height = ICONSIZE;
				
				[img drawInRect:r fromRect:r2 operation:NSCompositeSourceOver fraction:lineTransparency];
			}
		
			p.x = r.origin.x + ICONSIZE + 2;
			p.y = r.origin.y - 1;
			
			if (shouldDrawWaypointLabels) {
				[[wpt name] drawAtPoint:p withAttributes:nil];				
			}
		}
	}
}


- (void)drawCurrentPositionMarker {
	NSPoint p = [self pointForLocation:[mapSource location]];
	
	NSImage * img;
	NSRect r, r2;

	const int ICONSIZE = 13;
	int ISO2 = floor(ICONSIZE / 2);

	//the rectangle to draw the icon into
	r.origin.x = p.x - ISO2;
	r.origin.y = p.y - ISO2;
	r.size.width = ICONSIZE;
	r.size.height = ICONSIZE;
	
	//first, draw the background rectangle
	r2.size.width = ICONSIZE;
	r2.size.height = ICONSIZE;
	r2.origin = r.origin;
	
	[[[NSColor whiteColor] colorWithAlphaComponent:0.8] set];
	[[NSBezierPath bezierPathWithRect:r2] fill];
	
	//next, draw the image
	if (img = [NSImage imageNamed:@"marker_icon"]) {
		r2.origin.x = 0;
		r2.origin.y = 0;
		r2.size.width = ICONSIZE;
		r2.size.height = ICONSIZE;
		
		[img drawInRect:r fromRect:r2 operation:NSCompositeCopy fraction:0.8];
	}	
}


// draws a bar on the screen which shows the scale of the map
//
// Note - this method is not very efficient, and we don't need to re calculate 
// the bar every time - it should only be done once and then just draw the new scale
// (number of meters or feet) every time.
- (void)drawScaleBar {

	[[scaleBarColor colorWithAlphaComponent:lineTransparency] set];
		
	NSBezierPath * scaleBar = [[NSBezierPath bezierPath] retain];
	[scaleBar setLineWidth:lineWidth];
	
	NSPoint start, finish, p;

	const int HALFSCALEHEIGHT = 5;	// half the height of the scale bar
	const int SCALEWIDTH = 100;
	
	start.x = 15;
	start.y = 15;
	finish.x = start.x + SCALEWIDTH;
	finish.y = start.y;
	
	p = start;
	p.y -= HALFSCALEHEIGHT;
	
	[scaleBar moveToPoint:p];
	p.y += HALFSCALEHEIGHT + HALFSCALEHEIGHT;
	[scaleBar lineToPoint:p];
	[scaleBar moveToPoint:start];
	[scaleBar lineToPoint:finish];
	
	p = finish;
	p.y -= HALFSCALEHEIGHT;
	[scaleBar moveToPoint:p];
	p.y += HALFSCALEHEIGHT + HALFSCALEHEIGHT;
	[scaleBar lineToPoint:p];
	
	[scaleBar stroke];
	
	p = start;
	p.x += 5;
	p.y += 5;
	
	float meters = [mapSource metersPerPixel] * (float)SCALEWIDTH;
	
	DistanceFormatter * df = [[DistanceFormatter alloc] init];
	[df setUsesAutoFormatting:YES];	
	[df setUsesAbbreviation:NO];
	NSString* stringToDraw = nil;

	stringToDraw = [df stringForObjectValue:[NSNumber numberWithFloat:meters]];
	[df release];
		
	[stringToDraw drawAtPoint:p 
		  withAttributes:[NSDictionary dictionaryWithObject:scaleBarColor
													 forKey:NSForegroundColorAttributeName]];
}


// For use in DISTANCE_MODE, draws the distance between the clicked and the dragged
// points on the map.
- (void)drawDistanceMeasurement {
	if (justAClick) {
		[self redrawOnly];
		return;
	}
	
	// Figure out the distance between the point the user first clicked on
	// and the current mouse point.

	// Note that startPoint and endPoint are relative to the window, so we have
	// to convert their coordinates so they'll be relative to the view itself.
	NSPoint sp = [self convertPoint:startPoint fromView:nil];
	NSPoint ep = [self convertPoint:endPoint fromView:nil];
		
	Location * loc1 = [self locationForViewCoordinates:sp];
	Location * loc2 = [self locationForViewCoordinates:ep];

	float distance = [loc1 metricDistanceBetween:loc2];
	

	NSPoint labelPoint;
	labelPoint.x = sp.x + ((ep.x - sp.x) / 2);
	labelPoint.y = sp.y + ((ep.y - sp.y) / 2);
	
	// Draw this distance on the map.
	DistanceFormatter * df = [[DistanceFormatter alloc] init];
	[df setUsesAutoFormatting:YES];
	[df setUsesAbbreviation:NO];
	
	NSString* stringToDraw = nil;

	stringToDraw = [df stringForObjectValue:[NSNumber numberWithFloat:distance]];
	[df release];
	
	
	[stringToDraw drawAtPoint:labelPoint
			   withAttributes:[NSDictionary dictionaryWithObject:scaleBarColor
														  forKey:NSForegroundColorAttributeName]];
	
	// Draw the starting and ending points.
	NSRect r;

	NSPoint origin = sp;
	origin.x -= 4;
	origin.y -= 4;	
		 
	r.size.width = 8;
	r.size.height = 8;
	r.origin = origin;
	
	[[scaleBarColor colorWithAlphaComponent:0.8] set];
	[[NSBezierPath bezierPathWithOvalInRect:r] fill];
		
	origin = ep;
	origin.x -= 4;
	origin.y -= 4;
	r.origin = origin;
	
	[[NSBezierPath bezierPathWithOvalInRect:r] fill];
	
	// draw a line between the two points	
	NSBezierPath * connectingLine = [[NSBezierPath bezierPath] retain];
		
	[connectingLine setLineWidth:lineWidth];
	[connectingLine moveToPoint: sp];
	[connectingLine lineToPoint:ep];	
	[connectingLine closePath];
	[connectingLine stroke];	
}



#pragma mark - 
#pragma mark Delegate methods

// called after the finished resizing.  
- (void)viewDidEndLiveResize {

	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	
	[nc postNotificationName:@"MOOGotoWaypoint" object: [Waypoint waypointWithLocation:[mapSource location]]];
}

#pragma mark -
#pragma mark Other methods

// defines default cursor rectangles
- (void)resetCursorRects {
	NSRect rect = [self frame];
	
	switch ((int)currentMouseMode) {
		case DRAG_MODE:
			[self addCursorRect:rect cursor:[NSCursor openHandCursor]];			
			break;
		case DISTANCE_MODE:			
			// change the cursor to a closed hand.
			[self addCursorRect:rect cursor:[NSCursor crosshairCursor]];			
			break;
	}
}

- (BOOL)becomeFirstResponder {

	shouldDrawFocusRing = YES;
	[self setNeedsDisplay:YES];
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {

	shouldDrawFocusRing = NO;
	[self setNeedsDisplay:YES];
	return [super resignFirstResponder];
}


- (NSSize)mapSize {
	return [self frame].size;
}

- (void)dealloc {
	[backImage release];
	
	//remove this object as an observer in the NotificationCenter
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: self];
	
	[bottomLeftLocation release];
	[topRightLocation release];

	[mapSource release];
	
	[tracklogColor release];
	[routeColor release];
	[gridlineColor release];
	[scaleBarColor release];
	
	[gridlinePath release];
	[trackPaths release];
	[routePaths release];	
	
	[super dealloc];
}

@end
