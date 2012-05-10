//
//  JCTiledScrollView.m
//  
//  Created by Jesse Collis on 1/2/2012.
//  Copyright (c) 2012, Jesse Collis JC Multimedia Design. <jesse@jcmultimedia.com.au>
//  All rights reserved.
//
//  * Redistribution and use in source and binary forms, with or without 
//   modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright 
//   notice, this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright 
//   notice, this list of conditions and the following disclaimer in the 
//   documentation and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY 
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
//

#import "JCTiledScrollView.h"
#import "JCTiledView.h"
#import "JCAnnotation.h"
#import "JCAnnotationView.h"

@interface JCTiledScrollView () <JCTiledBitmapViewDelegate>
@property (nonatomic, retain) UIView *canvasView;
@property (nonatomic, retain) UITapGestureRecognizer *singleTapGestureRecognizer;
@property (nonatomic, retain) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (nonatomic, retain) UITapGestureRecognizer *twoFingerTapGestureRecognizer;

@end

@implementation JCTiledScrollView
{
  BOOL _suddenZoomChange;
}

@synthesize tiledScrollViewDelegate = _tiledScrollViewDelegate;
@synthesize dataSource = _dataSource;

@synthesize levelsOfZoom = _levelsOfZoom;
@synthesize levelsOfDetail = _levelsOfDetail;
@dynamic zoomScale;

@synthesize tiledView = _tiledView;
@synthesize scrollView = _scrollView;
@synthesize canvasView = _canvasView;

@synthesize singleTapGestureRecognizer = _singleTapGestureRecognizer;
@synthesize doubleTapGestureRecognizer = _doubleTapGestureRecognizer;
@synthesize twoFingerTapGestureRecognizer = _twoFingerTapGestureRecognizer;

@synthesize zoomsOutOnTwoFingerTap = _zoomsOutOnTwoFingerTap;
@synthesize zoomsInOnDoubleTap = _zoomsInOnDoubleTap;
@synthesize centerSingleTap = _centerSingleTap;

+ (Class)tiledLayerClass
{
  return [JCTiledView class];
}

- (id)initWithFrame:(CGRect)frame contentSize:(CGSize)contentSize
{
	if ((self = [super initWithFrame:frame]))
  {
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;

    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    _scrollView.delegate = self;
    _scrollView.backgroundColor = [UIColor whiteColor];
    _scrollView.contentSize = contentSize;
    _scrollView.bouncesZoom = YES;
    _scrollView.bounces = YES;
    _scrollView.minimumZoomScale = 1.0;
    [_scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];

    self.levelsOfZoom = 2;

    self.zoomsInOnDoubleTap = YES;
    self.zoomsOutOnTwoFingerTap = YES;
    self.centerSingleTap = YES;

    CGRect canvas_frame = CGRectMake(0.0f, 0.0f, _scrollView.contentSize.width, _scrollView.contentSize.height);
    _canvasView = [[UIView alloc] initWithFrame:canvas_frame];
    _canvasView.userInteractionEnabled = NO;

    _tiledView = [[[[self class] tiledLayerClass] alloc] initWithFrame:canvas_frame];
    _tiledView.delegate = self;

    [_scrollView addSubview:self.tiledView];

    [self addSubview:_scrollView];
    [self addSubview:_canvasView];

    _singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapReceived:)];
    _singleTapGestureRecognizer.numberOfTapsRequired = 1;
    [_tiledView addGestureRecognizer:_singleTapGestureRecognizer];

    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapReceived:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [_tiledView addGestureRecognizer:_doubleTapGestureRecognizer];

    [_singleTapGestureRecognizer requireGestureRecognizerToFail:_doubleTapGestureRecognizer];

    _twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerTapReceived:)];
    _twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2;
    _twoFingerTapGestureRecognizer.numberOfTapsRequired = 1;
    [_tiledView addGestureRecognizer:_twoFingerTapGestureRecognizer];
    
    _annotations = [[NSMutableSet alloc] init];
    _visibleAnnotations = [[NSMutableSet alloc] init];
    _recycledAnnotationViews = [[NSMutableSet alloc] init];

    _suddenZoomChange = NO;
	}
	return self;
}

- (void)dealloc
{	
  [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:NULL];
  RELEASE(_scrollView);
  RELEASE(_tiledView);
  RELEASE(_canvasView);
  RELEASE(_singleTapGestureRecognizer);
  RELEASE(_doubleTapGestureRecognizer);
  RELEASE(_twoFingerTapGestureRecognizer);
  
  RELEASE(_annotations);
  RELEASE(_visibleAnnotations);
  RELEASE(_recycledAnnotationViews);

	[super dealloc];
}

#pragma mark - UIScrolViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
  return self.tiledView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollViewDidZoom:)])
  {
    [self.tiledScrollViewDelegate tiledScrollViewDidZoom:self];
  }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollViewDidScroll:)])
  {
    [self.tiledScrollViewDelegate tiledScrollViewDidScroll:self];
  }
}

#pragma mark - Gesture Suport

- (void)singleTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.centerSingleTap)
  {
    [self setContentCenter:[gestureRecognizer locationInView:self.tiledView] animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveSingleTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveSingleTap:gestureRecognizer];
  }
}

- (void)doubleTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.zoomsInOnDoubleTap)
  {
    float newZoom = MIN(powf(2, (log2f(_scrollView.zoomScale) + 1.0f)), _scrollView.maximumZoomScale); //zoom in one level of detail
    [_scrollView setZoomScale:newZoom animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveDoubleTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveDoubleTap:gestureRecognizer];
  }
}

- (void)twoFingerTapReceived:(UITapGestureRecognizer *)gestureRecognizer
{
  if (self.zoomsOutOnTwoFingerTap)
  {
    float newZoom = MAX(powf(2, (log2f(_scrollView.zoomScale) - 1.0f)), _scrollView.minimumZoomScale); //zoom out one level of detail
    [_scrollView setZoomScale:newZoom animated:YES];
  }

  if ([self.tiledScrollViewDelegate respondsToSelector:@selector(tiledScrollView:didReceiveTwoFingerTap:)])
  {
    [self.tiledScrollViewDelegate tiledScrollView:self didReceiveTwoFingerTap:gestureRecognizer];
  }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (object == _scrollView && [keyPath isEqualToString:@"contentOffset"])
  {
    //    NSLog(@"old: %@ new-co: %@ zooming: %@ scale: %@ zoomChange: %d",[change valueForKey:NSKeyValueChangeOldKey],[change valueForKey:NSKeyValueChangeNewKey],_scrollView.isZooming?@"YES":@"NO", [NSNumber numberWithFloat:self.zoomScale], _suddenZoomChange   );

    if (self.zoomScale == _previousZoomScale)
    {
      [self correctScreenPositionOfAnnotations:NO];
      
//    if (_scrollView.isZooming)
//    {
//      [self correctScreenPositionOfAnnotations:YES];
//    }
    }
    else
    {
      [self correctScreenPositionOfAnnotations:YES];
      _previousZoomScale = self.zoomScale;
    }
  }
}

- (void)updateAnnotationScreenPosition:(JCAnnotation *)annotation
{
  CGPoint position;
  position.x = (annotation.contentPosition.x * self.zoomScale) - _scrollView.contentOffset.x;
  position.y = (annotation.contentPosition.y * self.zoomScale) - _scrollView.contentOffset.y;
  annotation.screenPosition = position;
}

- (void)correctScreenPositionOfAnnotations:(BOOL)zoom;
{
  [CATransaction begin];
  [CATransaction setAnimationDuration:0];
  
  if (zoom && !_scrollView.isZooming)
  {
    for (JCAnnotation *annotation in _visibleAnnotations)
    {
      [self updateAnnotationScreenPosition:annotation];
    }
  }
  else
  {
    for (JCAnnotation *annotation in _annotations)
    {
      [CATransaction begin];
      [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
      
      [self updateAnnotationScreenPosition:annotation];

      if ([annotation isWithinBounds:self.bounds])
      {
        if (!annotation.view)
        {
          annotation.view = [_tiledScrollViewDelegate tiledScrollView:self viewForAnnotation:annotation];;
          if (!annotation.view) continue;
        }
        
        if (![_visibleAnnotations containsObject:annotation])
        {
          [_canvasView addSubview:annotation.view];
          [CATransaction begin];
          CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
          theAnimation.duration = 0.3;
          theAnimation.repeatCount = 1;
          theAnimation.fromValue = [NSNumber numberWithFloat:0.0];
          theAnimation.toValue = [NSNumber numberWithFloat:1.0];
          [annotation.view.layer addAnimation:theAnimation forKey:@"animateOpacity"];
          [CATransaction commit];
          [_visibleAnnotations addObject:annotation];
        }
      }
      else
      {
        if ([_visibleAnnotations containsObject:annotation])
        {
          [annotation.view removeFromSuperview];
          [_recycledAnnotationViews addObject:annotation.view];
          annotation.view = nil;
          [_visibleAnnotations removeObject:annotation];
        }
      }
      [CATransaction commit];
    }
  }

  [CATransaction commit];
}

#pragma mark - JCTiledScrollView

- (float)zoomScale
{
  return _scrollView.zoomScale;
}

- (void)setZoomScale:(float)zoomScale
{
  _scrollView.zoomScale = zoomScale;
}

- (void)setLevelsOfZoom:(size_t)levelsOfZoom
{
  _levelsOfZoom = levelsOfZoom;
  _scrollView.maximumZoomScale = (float)powf(2.0f, MAX(0.0f, levelsOfZoom));
}

- (void)setLevelsOfDetail:(size_t)levelsOfDetail
{
  if (levelsOfDetail == 1) NSLog(@"Note: Setting levelsOfDetail to 1 causes strange behaviour");

  _levelsOfDetail = levelsOfDetail;
  [self.tiledView setNumberOfZoomLevels:levelsOfDetail];
}

- (void)setContentCenter:(CGPoint)center animated:(BOOL)animated
{
  CGPoint new_contentOffset;
  new_contentOffset.x = MAX(0.0f, (center.x * _scrollView.zoomScale) - (_scrollView.bounds.size.width / 2.0f));
  new_contentOffset.y = MAX(0.0f, (center.y * _scrollView.zoomScale) - (_scrollView.bounds.size.height / 2.0f));
  
  new_contentOffset.x = MIN(new_contentOffset.x, (_scrollView.contentSize.width - _scrollView.bounds.size.width));
  new_contentOffset.y = MIN(new_contentOffset.y, (_scrollView.contentSize.height - _scrollView.bounds.size.height));
  
  [_scrollView setContentOffset:new_contentOffset animated:animated];
}

#pragma mark - JCTileSource

- (UIImage *)tiledView:(JCTiledView *)tiledView imageForRow:(NSInteger)row column:(NSInteger)column scale:(NSInteger)scale
{
  return [self.dataSource tiledScrollView:self imageForRow:row column:column scale:scale];
}

#pragma mark - Dequeue Annotations

- (JCAnnotationView *)dequeueReusableAnnotationViewWithReuseIdentifier:(NSString *)reuseIdentifier
{
  id view = nil;

  for (JCAnnotationView *obj in _recycledAnnotationViews)
  {
    if ([[obj reuseIdentifier] isEqualToString:reuseIdentifier])
    {
      view = obj;
      break;
    }
  }
  
  if (nil != view)
  {
    [view retain];
    [_recycledAnnotationViews removeObject:view];
    return [view autorelease];
  }

  return nil;
}

#pragma mark - Annotations

- (void)addAnnotation:(JCAnnotation *)annotation
{
  [_annotations addObject:annotation];
  [self updateAnnotationScreenPosition:annotation];
  
  if ([annotation isWithinBounds:self.bounds])
  {
    [_visibleAnnotations addObject:annotation];
    
    annotation.view = [_tiledScrollViewDelegate tiledScrollView:self viewForAnnotation:annotation];
    [_canvasView addSubview:annotation.view];
  }
}

@end
