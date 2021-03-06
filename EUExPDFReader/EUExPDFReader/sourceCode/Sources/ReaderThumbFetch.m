//
//	ReaderThumbFetch.m
//	Reader v2.5.6
//
//	Created by asdkios on 2011-09-01.
//	Copyright © 2013-2014 asdkios. All rights reserved.
//

#import "ReaderThumbFetch.h"
#import "ReaderThumbRender.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbView.h"

#import <ImageIO/ImageIO.h>

@implementation ReaderThumbFetch

//#pragma mark Properties

//@synthesize ;

#pragma mark ReaderThumbFetch instance methods

- (id)initWithRequest:(ReaderThumbRequest *)object
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if ((self = [super initWithGUID:object.guid]))
	{
		request = [object retain];
	}

	return self;
}

- (void)dealloc
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if (request.thumbView.operation == self)
	{
		request.thumbView.operation = nil; // Done
	}

	[request release], request = nil;

	[super dealloc];
}

- (void)cancel
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	[[ReaderThumbCache sharedInstance] removeNullForKey:request.cacheKey];

	[super cancel];
}

- (NSURL *)thumbFileURL
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:request.guid]; // Thumb cache path

	NSString *fileName = [NSString stringWithFormat:@"%@.png", request.thumbName]; // Thumb file name

	return [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:fileName]]; // File URL
}

- (void)main
{
#ifdef DEBUGX
	NSLog(@"%s", __FUNCTION__);
#endif

	if (self.isCancelled == YES) return;

	NSURL *thumbURL = [self thumbFileURL]; CGImageRef imageRef = NULL;

	CGImageSourceRef loadRef = CGImageSourceCreateWithURL((CFURLRef)thumbURL, NULL);

	if (loadRef != NULL) // Load the existing thumb image
	{
		imageRef = CGImageSourceCreateImageAtIndex(loadRef, 0, NULL); // Load it

		CFRelease(loadRef); // Release CGImageSource reference
	}
	else // Existing thumb image not found - so create and queue up a thumb render operation on the work queue
	{
		ReaderThumbRender *thumbRender = [[ReaderThumbRender alloc] initWithRequest:request]; // Create a thumb render operation

		[thumbRender setQueuePriority:self.queuePriority]; [thumbRender setThreadPriority:(self.threadPriority - 0.1)]; // Priority

		if (self.isCancelled == NO) // We're not cancelled - so update things and add the render operation to the work queue
		{
			request.thumbView.operation = thumbRender; // Update the thumb view operation property to the new operation

			[[ReaderThumbQueue sharedInstance] addWorkOperation:thumbRender]; // Queue the operation
		}

		[thumbRender release]; // Release ReaderThumbRender object
	}

	if (imageRef != NULL) // Create UIImage from CGImage and show it
	{
		UIImage *image = [UIImage imageWithCGImage:imageRef scale:request.scale orientation:0];

		CGImageRelease(imageRef); // Release the CGImage reference from the above thumb load code

		UIGraphicsBeginImageContextWithOptions(image.size, YES, request.scale); // Graphics context

		[image drawAtPoint:CGPointZero]; // Decode and draw the image on this background thread

		UIImage *decoded = UIGraphicsGetImageFromCurrentImageContext(); // Newly decoded image

		UIGraphicsEndImageContext(); // Cleanup after the bitmap-based graphics drawing context

		[[ReaderThumbCache sharedInstance] setObject:decoded forKey:request.cacheKey]; // Update cache

		if (self.isCancelled == NO) // Show the image in the target thumb view on the main thread
		{
			ReaderThumbView *thumbView = request.thumbView; // Target thumb view for image show

			NSUInteger targetTag = request.targetTag; // Target reference tag for image show

			dispatch_async(dispatch_get_main_queue(), // Queue image show on main thread
			^{
				if (thumbView.targetTag == targetTag) [thumbView showImage:decoded];
			});
		}
	}
}

@end
