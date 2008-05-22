//
//  GPSFileParser.m
//  Terrabrowser
//
//  Created by Ryan on Sat Jan 10 2004.
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

#import "GPSFileParser.h"
#import "Waypoint.h"
#import "Ellipsoid.h"
#import "XMLElement.h"

//  this is a category of WaypointDocument

//  NSXMLParser - http://developer.apple.com/documentation/Cocoa/Reference/Foundation/ObjC_classic/Classes/NSXMLParser.html#//apple_ref/occ/cl/NSXMLParser 

@implementation WaypointDocument ( GPSFileParser )


#pragma mark -
#pragma mark XML (GPX) parsers and delegates

- (NSString*)gpxVersionSupported {
	return [NSString stringWithString: @"1.0"];
}


// parses a gpx file which is passed to it as a data string.
- (BOOL)parseAsGPXFile {
	
	if (! dataRep) {
		return NO;
	}
	
	containsUnsupportedElements = NO;
	
	[waypointList release];
	waypointList = [[XMLElement alloc] init];
	
	[trackList release];
	trackList = [[XMLElement alloc] init];
	
	[routeList release];
	routeList = [[XMLElement alloc] init];
	
	
	if (! XMLParser) {
		XMLParser = [[NSXMLParser alloc] initWithData:dataRep];	
	}
		
	[XMLParser setDelegate:self];
	
	// attempt to parse the file
	BOOL success = [XMLParser parse];	
	
	return success;
}

// START Element
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	
	//NSLog(@"didStartElement '%@'", elementName);
	//NSLog(@"currentStringBuffer = '%@'", currentStringBuffer);
	
	// empty the string buffer
	[currentStringBuffer release];
	currentStringBuffer = [[NSMutableString alloc] initWithCapacity:20];

	if ( [elementName isEqualToString:@"gpx"] ) {
		
		// grab a few attributes of this element
		gpxCreatorProgram = [attributeDict objectForKey:@"creator"];
		gpxVersion = [attributeDict objectForKey:@"version"];		
    } 
	
	else if ( [elementName isEqualToString:@"wpt"] ) {
		[wptTemp release];
		wptTemp = [[Waypoint alloc] init];  // create a new waypoint object
			
		// The lat and lon are stored in an attribute of the wpt element.
		[wptTemp setDoubleLatitude:  [[attributeDict objectForKey:@"lat"] doubleValue ]];
		[wptTemp setDoubleLongitude: [[attributeDict objectForKey:@"lon"] doubleValue ]];
		
		insideWpt = YES;	// set a flag so we know we're inside a wpt
    }
	
	else if ( [elementName isEqualToString:@"trk"] ) {
		[track release];
		track = [[XMLElement XMLElementWithName:elementName] retain];
		insideTrk = YES;
	}
	else if ( [elementName isEqualToString:@"trkseg"] ) {
		[trackSeg release];
		trackSeg = [[XMLElement XMLElementWithName:elementName] retain];
		insideTrkSeg = YES;
	}
	else if ( [elementName isEqualToString:@"trkpt"] ) {
		[trkpt release];
		trkpt = [[Waypoint alloc] init];
		[trkpt setElementName:elementName];
		
		// the lat and lon are stored in an attribute of the trkpt element.
		[trkpt setDoubleLatitude:  [[attributeDict objectForKey:@"lat"] doubleValue ]];
		[trkpt setDoubleLongitude: [[attributeDict objectForKey:@"lon"] doubleValue ]];
		
		insideTrkpt = YES;
	}
	else if ( [elementName isEqualToString:@"rte"] ) {
		[route release];
		route = [[XMLElement XMLElementWithName:elementName] retain];
		
		insideRte = YES;
	}
	else if ( [elementName isEqualToString:@"rtept"] ) {
		[rtept release];
		rtept = [[Waypoint alloc] init];
		[rtept setElementName:elementName];
		
		// the lat and lon are stored in an attribute of the rtept element.
		[rtept setDoubleLatitude:  [[attributeDict objectForKey:@"lat"] doubleValue ]];
		[rtept setDoubleLongitude: [[attributeDict objectForKey:@"lon"] doubleValue ]];
		
		insideRtept = YES;
	}
}


// FOUND Characters
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	//NSLog(@"foundCharacters: '%@'", string);
	
	if (currentStringBuffer) {
		[currentStringBuffer appendString:string];
    }
	
	//NSLog(@"currentStringBuffer = '%@'", currentStringBuffer);
}

// FOUND Ignorable Whitespace
- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString {
	//NSLog(@"foundIgnorableWhitespace = '%@'", whitespaceString);
	//[currentStringBuffer setString:@""];
}


// END Element
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	//NSLog(@"didEndElement '%@'", elementName);
	//NSLog(@"currentStringBuffer = '%@'", currentStringBuffer);
		
	if ( [elementName isEqualToString:@"wpt"] ) {
		[waypointList addElementToList:wptTemp];
		insideWpt = NO;		// we're no longer in this wpt
	}
	else if ( [elementName isEqualToString:@"trk"] ) {
		if (trackList != nil) [trackList addElementToList:track];
		insideTrk = NO;
	}
	else if ( [elementName isEqualToString:@"trkseg"] ) {
		if (track != nil) [track addElementToList:trackSeg];
		insideTrkSeg = NO;
	}
	else if ( [elementName isEqualToString:@"trkpt"] ) {
		if (trackSeg != nil) [trackSeg addElementToList:trkpt];		
		insideTrkpt = NO;
	}
	else if ( [elementName isEqualToString:@"rte"] ) {
		if (routeList != nil) [routeList addElementToList:route];
		insideRte = NO;
	}
	else if ( [elementName isEqualToString:@"rtept"] ) {
		if (route != nil) [route addElementToList:rtept];
		insideRtept = NO;
	}
	
	
	if (currentStringBuffer == nil) {
		return;
	}
	
	
	// if we're within a <wpt>, <trkpt>, or <rtept>, then 
	// add each element to the list in the current Waypoint object.
	if (insideWpt) {
		[wptTemp setElement:currentStringBuffer forKey:elementName];
	}
	else if (insideTrkpt) {
		[trkpt setElement:currentStringBuffer forKey:elementName];
	}
	else if (insideRtept) {
		[rtept setElement:currentStringBuffer forKey:elementName];
	}
	else if (insideRte) {
		[route setElement:currentStringBuffer forKey:elementName];
	}
	else if (insideTrkSeg) {
		[trackSeg setElement:currentStringBuffer forKey:elementName];
	}
	else if (insideTrk) {
		[track setElement:currentStringBuffer forKey:elementName];
	}
	else {
		// we'll assume that the tag belongs in the top GPX tag.
		if ( [elementName isEqualToString:@"author"] ) {
			creatorName = [currentStringBuffer retain];
		}		
		else if ( [elementName isEqualToString:@"email"] ) {
			creatorEmail = [currentStringBuffer retain];
		}		
		else if ( [elementName isEqualToString:@"keywords"] ) {
			keywords = [currentStringBuffer retain];
		}
		else if ( [elementName isEqualToString:@"url"] ) {
			gpxURL = [currentStringBuffer retain];
		}		
		else if ( [elementName isEqualToString:@"urlname"] ) {
			gpxURLName = [currentStringBuffer retain];
		}		
		else {
			//[otherElements setObject:currentStringBuffer forKey:elementName];
		}
	}
	
	[currentStringBuffer release];
	currentStringBuffer = nil;
}

// ERROR Occurred
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	NSLog(@"An XML parse error has occurred, aborting!\n%@", [parseError localizedDescription]);
	[XMLParser abortParsing];
	
	// note, shouldn't have to do this, but the abortParsing doesn't seem to stop it fast enough
	// setting the delgate to nil prevents the entire program from crashing.
	[XMLParser setDelegate:nil];
}


// END Document
- (void)parserDidEndDocument:(NSXMLParser *)parser {
	// for now, we'll release it upon the end of parsing to save memory.
	[XMLParser release];
	XMLParser = nil;
	
	[wptTemp release];
	
	if (containsUnsupportedElements == YES) {
		NSRunCriticalAlertPanel(@"GPX Compatibility Warning", 
							@"This GPX file contains elements which are not supported by Terrabrowser.  Saving the file from within Terrabrowser will result in the unsupported elements being lost.  If you still want to save the file, you should consider making a backup copy of it first.",
							@"Okay", @"Darn!", @"", nil);
	}
}


#pragma mark -
#pragma mark Other parsers


- (void)parseAsCSVFileWithDelimiter:(char)d {
	
}

- (void)parseAsLOCFile {
	
}



#pragma mark -
#pragma mark UnParsers


// takes the waypointList, trackList, and routeList and creates
// a GPX formatted string from them.
//
// see http://www.topografix.com/gpx.asp
//
- (NSString*)gpxString {

	NSString *currentVersion = [[[NSBundle bundleForClass:[self class]]
		infoDictionary] objectForKey:@"CFBundleVersion"];
	
	NSString * header = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"ISO-8859-1\" standalone=\"yes\"?>\n <gpx version=\"1.0\"\n creator=\"Terrabrowser %@ - http://www.chimoosoft.com/terrabrowser.html\"\n xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n xmlns=\"http://www.topografix.com/GPX/1/0\"\n xsi:schemaLocation=\"http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd http://www.topografix.com/GPX/Private/TopoGrafix/0/2 http://www.topografix.com/GPX/Private/TopoGrafix/0/2/topografix.xsd\">\n", currentVersion];
	NSMutableString * gpx = [NSMutableString stringWithString:header];
	
	if ([creatorName length] > 0) [gpx appendFormat: @"<author>%@</author>\n", creatorName];
	if ([creatorEmail length] > 0) [gpx appendFormat: @"<email>%@</email>\n", creatorEmail];
	if ([keywords length] > 0) [gpx appendFormat: @"<keywords>%@</keywords>\n", keywords];
	if ([gpxDescription length] > 0) [gpx appendFormat: @"<desc>%@</desc>\n", gpxDescription];
	if ([gpxURL length] > 0) [gpx appendFormat: @"<url>%@</url>\n", gpxURL];
	if ([gpxURLName length] > 0) [gpx appendFormat: @"<urlname>%@</urlname>\n", gpxURLName];
	
	NSEnumerator * enumerator;
	
	// now, write out any other GPX elements which we don't directly support, but which we 
	// read in and stored in the otherElements dictionary.
	
	enumerator = [otherElements keyEnumerator];
	id key;
	while (key = [enumerator nextObject]) {
		[gpx appendFormat:@"<%@>%@</%@>", key, [otherElements valueForKey:key] , key];
	}
		
	
	// Waypoints
	//===========
	id obj;
	enumerator = [waypointList objectEnumerator];

	while (obj = [enumerator nextObject]) {
		[gpx appendString:[(Waypoint*)obj gpxString]];
	}	
	
	
	// Track logs
	//===========

	enumerator = [trackList objectEnumerator];
	while (obj = [enumerator nextObject]) {
		[gpx appendString:[(XMLElement*)obj gpxString]];
	}	

	// Routes
	//===========

	enumerator = [routeList objectEnumerator];
	while (obj = [enumerator nextObject]) {
		[gpx appendString:[(XMLElement*)obj gpxString]];
	}	
	
	[gpx appendString:@"</gpx>"];
	
	return gpx;
}


- (NSString*)locString {
	return nil;
}

- (NSString*)csvStringWithDelimiter:(char)d {
	return nil;
}



@end
