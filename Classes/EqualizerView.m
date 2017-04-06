//
//  EqualizerPointView.m
//  iSub
//
//  Created by Ben Baron on 11/23/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import "OpenGLCommon.h"
#import "ConstantsAndMacros.h"

#import "EqualizerView.h"

//CLASS IMPLEMENTATIONS:

// A class extension to declare private methods
@interface EqualizerView (private)

- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;

@end

@implementation EqualizerView

static float drawInterval = 1./20.;
static int specWidth; //256 or 512
static int specHeight; //256 or 512

static CGContextRef specdc;
static DWORD *specbuf;
static DWORD *palette;
int specpos = 0;

typedef struct 
{
	BYTE rgbRed, rgbGreen, rgbBlue, Aplha;
} RGBQUAD;

static void SetupArrays()
{
	if (SCREEN_SCALE() == 1.0)// && !IS_IPAD())
		specWidth = specHeight = 256;
	else
		specWidth = specHeight = 512;
	
	specbuf = malloc(specWidth * specHeight * 4);
	palette = malloc((specHeight + 128) * 4);
	
	memset(palette, 0, ((specHeight + 128) * 4));
}

static void SetupDrawEQPalette()
{
	float scale = SCREEN_SCALE();
	
	// setup palette
	RGBQUAD *pal = (RGBQUAD *)palette;
	int a;
	/*for (a = 1; a < 65; a++) 
	 {
	 pal[a].rgbRed = 130 - 2 * a;
	 pal[a].rgbBlue = 126 + 2 * a;
	 }
	 for (a = 1; a < 128; a++) 
	 {
	 pal[64+a].rgbBlue = 256 - 2 * a;
	 pal[64+a].rgbGreen   = 2 * a;
	 }
	 for (a = 1; a < 128; a++) 
	 {
	 pal[191+a].rgbGreen = 256 - 2 * a;
	 pal[191+a].rgbRed   = 2 * a;
	 }
	 for (a = 1; a < SPECHEIGHT - 318; a++)
	 {
	 pal[318+a].rgbRed = 255;
	 }*/
	
	for (a = 1; a < 128 * scale; a++) 
	{
		pal[a].rgbBlue = 256 - ((2/scale) * a);
		pal[a].rgbGreen   = (2/scale) * a;
	}
    for (a = 1; a < 128 * scale; a++) 
	{
		int start = 128 * scale - 1;
		pal[start+a].rgbGreen = 256 - ((2/scale) * a);
		pal[start+a].rgbRed   = (2/scale) * a;
	}
	
	for (a = 0; a < 32; a++) 
	{
		pal[specHeight + a].rgbBlue       = 8 * a;
		pal[specHeight + 32 + a].rgbBlue  = 255;
		pal[specHeight + 32 + a].rgbRed   = 8 * a;
		pal[specHeight + 64 + a].rgbRed   = 255;
		pal[specHeight + 64 + a].rgbBlue  = 8 * (31 - a);
		pal[specHeight + 64 + a].rgbGreen = 8 * a;
		pal[specHeight + 96 + a].rgbRed   = 255;
		pal[specHeight + 96 + a].rgbGreen = 255;
		pal[specHeight + 96 + a].rgbBlue  = 8 * a;
	}
}

//- (void)createBitmapToDraw
static void SetupDrawBitmap()
{
	// create the bitmap
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	specdc = CGBitmapContextCreate(specbuf, specWidth, specHeight, 8, specWidth * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
	CGColorSpaceRelease(colorSpace);
}

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (id)setup
{
    SetupArrays();
    SetupDrawEQPalette();
    SetupDrawBitmap();
    
	self.userInteractionEnabled = YES;
	
	self.drawTimer = nil;
	
	//[self createBitmapToDraw];
	
	//[self setupPalette];
	
	CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
	
	eaglLayer.opaque = YES;
	// In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
	eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
									@YES, kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
	
	context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	
	if (!context || ![EAGLContext setCurrentContext:context])
	{
		return nil;
	}
	
	// Use OpenGL ES to generate a name for the texture.
	glGenTextures(1, &imageTexture);
	// Bind the texture name. 
	glBindTexture(GL_TEXTURE_2D, imageTexture);
	// Set the texture parameters to use a minifying filter and a linear filer (weighted average)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	
	//Set up OpenGL states
	glMatrixMode(GL_PROJECTION);
	CGRect frame = self.bounds;
	glOrthof(0, frame.size.width, 0, frame.size.height, -1, 1);
	glViewport(0, 0, frame.size.width, frame.size.height);
	glMatrixMode(GL_MODELVIEW);
	
	glDisable(GL_DITHER);
	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnable(GL_POINT_SPRITE_OES);
	glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
	
	[self changeType:settingsS.currentVisualizerType];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopEqDisplay) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startEqDisplay) name:UIApplicationDidBecomeActiveNotification object:nil];
	
	return self;
}

// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder 
{
    if ((self = [super initWithCoder:coder]))
	{
		return [self setup];
	}
	
	return self;
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		return [self setup];
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    CGContextRelease(specdc);
    free(palette);
    free(specbuf);
    
    [self.drawTimer invalidate];
    
    if (imageTexture)
    {
        glDeleteTextures(1, &imageTexture);
        imageTexture = 0;
    }
    
    if([EAGLContext currentContext] == context)
    {
        [EAGLContext setCurrentContext:nil];
    }
    
}

- (void)startEqDisplay
{
	//DLog(@"starting eq display");
	self.drawTimer = [NSTimer scheduledTimerWithTimeInterval:drawInterval target:self selector:@selector(drawTheEq) userInfo:nil repeats:YES];
}

- (void)stopEqDisplay
{
	//DLog(@"stopping eq display");
	[self.drawTimer invalidate];
    self.drawTimer = nil;
}

- (void)createBitmapToDraw
{
	// create the bitmap
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	specdc = CGBitmapContextCreate(specbuf, specWidth, specHeight, 8, specWidth * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
	CGColorSpaceRelease(colorSpace);
}

- (void)drawTheEq
{		
	if (!audioEngineS.player.isPlaying || self.visualType == ISMSBassVisualType_none)
		return;
	
	[audioEngineS.visualizer readAudioData];
	
    int x = 0, y = 0, y1 = 0;

	switch(self.visualType)
	{
		case ISMSBassVisualType_none:
		case ISMSBassVisualType_maxValue:
			break;
		case ISMSBassVisualType_line:
		{
			[self eraseBitBuffer];
			for (x = 0; x < specWidth; x++) 
			{
				int v=(32767 - [audioEngineS.visualizer lineSpecData:x]) * specHeight/65536; // invert and scale to fit display
				if (!x) 
					y = v;
				do 
				{ 
					// draw line from previous sample...
					if (y < v)
						y++;
					else if (y > v)
						y--;
					specbuf[y * specWidth + x] = palette[abs(y - specHeight / 2) * 2 + 1];
				} while (y!=v);
			}
			break;
		}
		case ISMSBassVisualType_skinnyBar:
		{
			[self eraseBitBuffer];
			for (x=0;x<specWidth/2;x++) 
			{
#if 1
				y=sqrt([audioEngineS.visualizer fftData:x+1]) * 3 * specHeight - 4; // scale it (sqrt to make low values more visible)
#else
				y=[audioEngineS fftData:x+1] * 10 * specHeight; // scale it (linearly)
#endif
				if (y>specHeight) y=specHeight; // cap it
				if (x && (y1=(y+y1)/2)) // interpolate from previous to make the display smoother
					while (--y1>=0) specbuf[(specHeight-1-y1)*specWidth+x*2-1]=palette[y1+1];
				y1=y;
				while (--y>=0) specbuf[(specHeight-1-y)*specWidth+x*2]=palette[y+1]; // draw level
			}
			break;
		}
		case ISMSBassVisualType_fatBar:
		{
			int b0 = 0;
			[self eraseBitBuffer];
#define BANDS 28
			for (x=0; x < BANDS; x++) 
			{
				float peak = 0;
				int b1 = pow(2, x * 10.0 / (BANDS - 1));
				if (b1 > 1023)
					b1 = 1023;
				if (b1 <= b0)
					b1 = b0 + 1; // make sure it uses at least 1 FFT bin
				
				for (; b0 < b1; b0++)
				{
					if (peak < [audioEngineS.visualizer fftData:1+b0])
						peak = [audioEngineS.visualizer fftData:1+b0];
				}
				
				y = sqrt(peak) * 3 * specHeight - 4; // scale it (sqrt to make low values more visible)
				
				if (y > specHeight) 
					y = specHeight; // cap it
				
				while (--y >= 0)
				{
					for (y1 = 0; y1 < specWidth / BANDS - 2; y1++)
					{	
						specbuf[(specHeight - 1 - y) * specWidth + x * (specWidth / BANDS) + y1] = palette[y + 1]; // draw bar
					}
				}
			}
			break;
		}
		case ISMSBassVisualType_aphexFace:
		{
			for (x=0; x < specHeight; x++) 
			{
				y = sqrt([audioEngineS.visualizer fftData:x+1]) * 3 * 127; // scale it (sqrt to make low values more visible)
				if (y > 127)
					y = 127; // cap it
				specbuf[(specHeight - 1 - x) * specWidth + specpos] = palette[specHeight - 1 + y]; // plot it
			}
			// move marker onto next position
			specpos = (specpos + 1) % specWidth;
			for (x = 0; x < specHeight; x++)
			{
				specbuf[x * specWidth + specpos] = palette[specHeight+126];
				
				if (SCREEN_SCALE() == 2.0 && specpos + 1 < specWidth)
					specbuf[x * specWidth + specpos + 1] = palette[specHeight+126];
			}
			break;
		}
	}
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, specWidth, specHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, specbuf);
	
	[EAGLContext setCurrentContext:context];
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	
	GLfloat width = self.frame.size.width;
	GLfloat height = self.frame.size.height;
	GLfloat box[] = 
	{   0,     height, 0, 
		width, height, 0,
		width,      0, 0,
	    0,          0, 0 };
	GLfloat tex[] = {0,0, 1,0, 1,1, 0,1};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glVertexPointer(3, GL_FLOAT, 0, box);
	glTexCoordPointer(2, GL_FLOAT, 0, tex);
	
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	//Display the buffer
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	UIApplicationState state = [UIApplication sharedApplication].applicationState;
	if (state == UIApplicationStateActive)
	{
		// Make sure we didn't resign active while the method was already running
		[context presentRenderbuffer:GL_RENDERBUFFER_OES];
	}
}

// If our view is resized, we'll be asked to layout subviews.
// This is the perfect opportunity to also update the framebuffer so that it is
// the same size as our display area.
- (void)layoutSubviews
{
	//DLog(@"self.layer.frame: %@", NSStringFromCGRect(self.layer.frame));
	//self.layer.frame = self.frame;
	//DLog(@"self.layer.frame: %@", NSStringFromCGRect(self.layer.frame));
	NSLog(@"  ");
	
	[EAGLContext setCurrentContext:context];
	
	glMatrixMode(GL_PROJECTION);
    CGRect frame = self.bounds;
    CGFloat scaleFactor = self.contentScaleFactor;
    glLoadIdentity();
    glOrthof(0, frame.size.width * scaleFactor, 0, frame.size.height * scaleFactor, -1, 1);
    glViewport(0, 0, frame.size.width * scaleFactor, frame.size.height * scaleFactor);
    glMatrixMode(GL_MODELVIEW);
	
	[self destroyFramebuffer];
	[self createFramebuffer];
	
	// Clear the framebuffer the first time it is allocated
	if (needsErase) 
	{
		[self erase];
		needsErase = NO;
	}
}

- (BOOL)createFramebuffer
{
	// Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	glGenRenderbuffersOES(1, &depthRenderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}

// Clean up any buffers we have allocated.
- (void)destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

// Erases the screen
- (void)erase
{
	[EAGLContext setCurrentContext:context];
	
	//Clear the buffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0., 0., 0., 0.);
	glClear(GL_COLOR_BUFFER_BIT);
	
	//Display the buffer
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)eraseBitBuffer
{
	memset(specbuf, 0, (specWidth * specHeight * 4));
}

- (void)changeType:(ISMSBassVisualType)type
{
	switch (type)
	{
		case ISMSBassVisualType_none:
			audioEngineS.visualizer.type = BassVisualizerTypeNone;
			[self eraseBitBuffer];
			[self erase];
			self.visualType = ISMSBassVisualType_none;
			break;
			
		case ISMSBassVisualType_line:
			audioEngineS.visualizer.type = BassVisualizerTypeLine;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			self.visualType = ISMSBassVisualType_line; 
			break;
			
		case ISMSBassVisualType_skinnyBar:
			audioEngineS.visualizer.type = BassVisualizerTypeFFT;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			self.visualType = ISMSBassVisualType_skinnyBar; 
			break;
			
		case ISMSBassVisualType_fatBar:
			audioEngineS.visualizer.type = BassVisualizerTypeFFT;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			self.visualType = ISMSBassVisualType_fatBar;
			break;
			
		case ISMSBassVisualType_aphexFace:
			audioEngineS.visualizer.type = BassVisualizerTypeFFT;
			[self eraseBitBuffer];
            specpos = 0;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			self.visualType = ISMSBassVisualType_aphexFace; 
			break;
			
		case ISMSBassVisualType_maxValue:
			break;
	}
	settingsS.currentVisualizerType = self.visualType;
	//DLog(@"visualType: %i   currentVisualizerType: %i", visualType, settingsS.currentVisualizerType);
}

- (void)nextType
{
	int newType = self.visualType + 1;
	if (newType == ISMSBassVisualType_maxValue)
		newType = 0;
	
	[self changeType:newType];
}

- (void)prevType
{
	int newType = self.visualType - 1;
	if (newType < 0)
		newType = ISMSBassVisualType_maxValue - 1;
	
	[self changeType:newType];
}

/*- (void)changeType
{
	ISMSBassVisualType type = 0;
	switch (visualType)
	{
		case ISMSBassVisualType_none:
			type = ISMSBassVisualType_skinnyBar; break;
		case ISMSBassVisualType_skinnyBar:
			type = ISMSBassVisualType_fatBar; break;
		case ISMSBassVisualType_fatBar:
			type = ISMSBassVisualType_aphexFace; break;
		case ISMSBassVisualType_aphexFace:
			type = ISMSBassVisualType_line; break;
		case ISMSBassVisualType_line:
			type = ISMSBassVisualType_none; break;
	}
	[self changeType:type];
}*/

@end
