//
//  StatusItemView.m
//  HWMonitor
//
//  Created by kozlek on 23.02.13.
//  Copyright (c) 2013 kozlek. All rights reserved.
//

/*
 *  Copyright (c) 2013 Natan Zalkin <natan.zalkin@me.com>. All rights reserved.
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 *  02111-1307, USA.
 *
 */

#import "StatusItemView.h"

#import "HWMonitorDefinitions.h"
#import "HWMConfiguration.h"
#import "HWMEngine.h"
#import "HWMIcon.h"
#import "HWMSensor.h"
#import "HWMFavorite.h"

@implementation StatusItemView

@synthesize favoritesSnapshot = _favoritesSnapshot;

#pragma mark -
#pragma mark Properties

- (void)setHighlighted:(BOOL)isHighlighted
{
    if (_isHighlighted != isHighlighted) {
        _isHighlighted = isHighlighted;
    }
}

-(HWMEngine *)monitorEngine
{
    return [HWMEngine sharedEngine];
}

//-(void)setMonitorEngine:(HWMEngine *)monitorEngine
//{
//    if (self.monitorEngine != monitorEngine) {
//
//        if (self.monitorEngine) {
//            [[NSNotificationCenter defaultCenter] removeObserver:self name:HWMEngineSensorValuesHasBeenUpdatedNotification object:self.monitorEngine];
//        }
//
//        self.monitorEngine = monitorEngine;
//
//        if (self.monitorEngine) {
//            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:HWMEngineSensorValuesHasBeenUpdatedNotification object:self.monitorEngine];
//        }
//    }
//}

-(NSArray *)favoritesSnapshot
{
    if (!_favoritesSnapshot) {
        _favoritesSnapshot = [self.monitorEngine.favorites copy];
    }

    return _favoritesSnapshot;
}

#pragma mark -
#pragma mark Override

-(id)initWithFrame:(NSRect)rect statusItem:(NSStatusItem *)statusItem;
{
    self = [super initWithFrame:rect];

    if (self && statusItem) {
        _statusItem = statusItem;

        _smallFont = [NSFont fontWithName:@"Lucida Grande Bold" size:9.0];
        _bigFont = [NSFont fontWithName:@"Lucida Grande" size:13.9];

        _shadow = [[NSShadow alloc] init];

        [_shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.50]];
        [_shadow setShadowOffset:CGSizeMake(0, -1.0)];
        [_shadow setShadowBlurRadius:1.0];

        [_statusItem setView:self];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self addObserver:self forKeyPath:@keypath(self, monitorEngine.favorites) options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useBigFontInMenubar) options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useShadowEffectsInMenubar) options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useFahrenheit) options:NSKeyValueObservingOptionNew context:nil];

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:HWMEngineSensorValuesHasBeenUpdatedNotification object:self.monitorEngine];
        }];
    }

    return self;
}

-(void)dealloc
{
    [self removeObserver:self forKeyPath:@keypath(self, monitorEngine.favorites)];
    [self removeObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useBigFontInMenubar)];
    [self removeObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useShadowEffectsInMenubar)];
    [self removeObserver:self forKeyPath:@keypath(self, monitorEngine.configuration.useFahrenheit)];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawRect:(NSRect)rect
{
    //[_statusItem drawStatusBarBackgroundInRect:rect withHighlight:_isHighlighted];

    CGContextRef cgContext = [[NSGraphicsContext currentContext] graphicsPort];

    CGContextSetShouldSmoothFonts(cgContext, !self.monitorEngine.configuration.useBigFontInMenubar.boolValue);

    __block int offset = 3;

    if (self.monitorEngine) {

        if (!self.favoritesSnapshot.count) {

            [[NSGraphicsContext currentContext] saveGraphicsState];

            if (/*!_isHighlighted &&*/ self.monitorEngine.configuration.useShadowEffectsInMenubar.boolValue)
                [_shadow set];

            NSImage *image = /*_isHighlighted ? _alternateImage :*/ _image;

            if (image) {
                NSUInteger width = [image size].width + 12;

                [image drawAtPoint:NSMakePoint(lround((width - [image size].width) / 2), lround(([self frame].size.height - [image size].height) / 2)) fromRect:NSMakeRect(0, 0, width, [image size].height) operation:NSCompositeSourceOver fraction:1.0];

                [self setFrameSize:NSMakeSize(width, [self frame].size.height)];
            }

            [[NSGraphicsContext currentContext] restoreGraphicsState];

            //snow leopard icon & text problem
            [_statusItem setLength:([self frame].size.width)];

            return;
        }

        NSAttributedString *spacer = [[NSAttributedString alloc] initWithString:self.monitorEngine.configuration.useBigFontInMenubar.boolValue ? @" " : @"  " attributes:[NSDictionary dictionaryWithObjectsAndKeys:self.monitorEngine.configuration.useBigFontInMenubar.boolValue ? _bigFont : _smallFont, NSFontAttributeName, nil]];

        __block int lastWidth = 0;
        __block int index = 0;

        [self.favoritesSnapshot enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            HWMFavorite *favorite = (HWMFavorite *)obj;
            HWMFavorite *next = idx + 1 < self.favoritesSnapshot.count ? [self.favoritesSnapshot objectAtIndex:idx + 1] : nil;

            HWMItem *item = favorite.item;

            if ([item isKindOfClass:[HWMIcon class]]) {

                HWMIcon *icon = (HWMIcon*)item;

                if (self.favoritesSnapshot.count == 1) {
                    offset += 3;
                }

                [[NSGraphicsContext currentContext] saveGraphicsState];

                NSImage *image = /*_isHighlighted ? [icon alternateImage] :*/ icon.regular;

                if (image) {

                    if (image.isTemplate && self.monitorEngine.configuration.useShadowEffectsInMenubar.boolValue)
                        [_shadow set];

                    [image drawAtPoint:NSMakePoint(offset, lround(([self frame].size.height - [image size].height) / 2)) fromRect:NSMakeRect(0, 0, [image size].width, [image size].height) operation:NSCompositeSourceOver fraction:1.0];

                    offset = offset + [image size].width + (next && [next.item isKindOfClass:[HWMSensor class]] ? 2 : idx + 1 == self.favoritesSnapshot.count ? 0 : [spacer size].width);

                    index = 0;
                }

                [[NSGraphicsContext currentContext] restoreGraphicsState];

                if (self.favoritesSnapshot.count == 1) {
                    offset += 3;
                }
            }
            else if ([item isKindOfClass:[HWMSensor class]]) {

                HWMSensor *sensor = (HWMSensor*)item;

                NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:sensor.strippedValue];

                NSColor *valueColor;

                switch (sensor.alarmLevel) {
                    case kHWMSensorLevelModerate:
                        valueColor = [NSColor colorWithCalibratedRed:0.7f green:0.3f blue:0.03f alpha:1.0f];
                        break;

                    case kHWMSensorLevelHigh:
                    case kHWMSensorLevelExceeded:
                        valueColor = [NSColor redColor];
                        break;

                    default:
                        valueColor = [NSColor blackColor];
                        break;
                }

                [title addAttribute:NSForegroundColorAttributeName value:(/*_isHighlighted ? [NSColor whiteColor] :*/ valueColor) range:NSMakeRange(0,[title length])];

                [[NSGraphicsContext currentContext] saveGraphicsState];

                if (/*!_isHighlighted &&*/ self.monitorEngine.configuration.useShadowEffectsInMenubar.boolValue)
                    [_shadow set];

                if (favorite.large.boolValue || self.monitorEngine.configuration.useBigFontInMenubar.boolValue) {

                    [title addAttribute:NSFontAttributeName value:_bigFont range:NSMakeRange(0, [title length])];
                    [title drawAtPoint:NSMakePoint(offset, lround(([self frame].size.height - [title size].height) / 2))];

                    offset += [title size].width  + (idx + 1 < self.favoritesSnapshot.count ? [spacer size].width : 0);

                    index = 0;
                }
                else {
                    int row = index % 2;

                    [title addAttribute:NSFontAttributeName value:_smallFont range:NSMakeRange(0, [title length])];
                    [title drawAtPoint:NSMakePoint(offset, self.favoritesSnapshot.count == 1 ? lround(([self frame].size.height - [title size].height) / 2) + 1 : row == 0 ? lround([self frame].size.height / 2) - 1 : lround([self frame].size.height / 2) - [title size].height + 2)];

                    int width = [title size].width;

                    if (row == 0) {
                        if (idx + 1 == self.favoritesSnapshot.count) {
                            offset += width;
                        }
                        else if (next && !([next.item isKindOfClass:[HWMSensor class]] && !next.large.boolValue)) {
                            offset += width + [spacer size].width;
                        }
                    }
                    else if (row == 1) {
                        width = width > lastWidth ? width : lastWidth;
                        offset += width + (idx + 1 < self.favoritesSnapshot.count ? [spacer size].width : 0);
                    }
                    
                    lastWidth = width;
                    
                    index++;
                }
                
                [[NSGraphicsContext currentContext] restoreGraphicsState];
            }

        }];
    }


    offset += 3;

    [self setFrameSize:NSMakeSize(offset, [self frame].size.height)];

    //snow leopard icon & text problem
    [_statusItem setLength:([self frame].size.width)];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [NSApp sendAction:self.action to:self.target from:self];
}

#pragma mark -
#pragma mark Methods

-(void)refresh
{
    [self setNeedsDisplay:YES];
}

-(NSRect)screenRect
{
    return [self.window convertRectToScreen:self.frame];
}

#pragma mark -
#pragma mark Events

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@keypath(self, monitorEngine.favorites)]) {

        _favoritesSnapshot = nil;

        [self refresh];

    }
    else if ([keyPath isEqualToString:@keypath(self, monitorEngine.configuration.useBigFontInMenubar)] || [keyPath isEqualToString:@keypath(self, monitorEngine.configuration.useShadowEffectsInMenubar)] || [keyPath isEqualToString:@keypath(self, monitorEngine.configuration.useFahrenheit)]) {

        [self refresh];

    }

    //[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
