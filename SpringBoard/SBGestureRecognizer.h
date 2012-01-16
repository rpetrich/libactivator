#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct __SBGestureContext *SBGestureContextRef;

typedef struct {
	int type;
	unsigned pathIndex;
	CGPoint location;
	CGPoint previousLocation;
	CGFloat totalDistanceTraveled;
	UIInterfaceOrientation interfaceOrientation;
	UIInterfaceOrientation previousInterfaceOrientation;
} SBGestureRecognizerTouchData;

@class SBTouchTemplate;

@interface SBGestureRecognizer : NSObject {
	int m_types;
	int m_state;
	id m_handler;
	unsigned m_activeTouchesCount;
	SBGestureRecognizerTouchData m_activeTouches[30];
	unsigned m_strikes;
	unsigned m_templateMatches;
	NSMutableArray *m_touchTemplates;
	BOOL m_includedInGestureRecognitionIsPossibleTest;
	BOOL m_sendsTouchesCancelledToApplication;
	id m_canBeginCondition;
}
@property(assign, nonatomic) int types;
@property(assign, nonatomic) int state;
@property(copy, nonatomic) void (^handler)(void);
@property(assign, nonatomic) BOOL includedInGestureRecognitionIsPossibleTest;
@property(assign, nonatomic) BOOL sendsTouchesCancelledToApplication;
@property(copy, nonatomic) BOOL (^canBeginCondition)(void);

- (BOOL)shouldReceiveTouches;
- (void)reset;
- (void)sendTouchesCancelledToApplicationIfNeeded;
- (void)addTouchTemplate:(SBTouchTemplate *)touchTemplate;
- (int)templateMatch;
- (void)touchesBegan:(SBGestureContextRef)context;
- (void)touchesMoved:(SBGestureContextRef)context;
- (void)touchesEnded:(SBGestureContextRef)context;
- (void)touchesCancelled:(SBGestureContextRef)context;
@end

@interface SBFluidSlideGestureRecognizer : SBGestureRecognizer {
	int m_degreeOfFreedom;
	unsigned m_minTouches;
	BOOL m_blocksIconController;
	CGFloat _animationDistance;
	CGFloat _commitDistance;
	CGFloat _accelerationThreshold;
	CGFloat _accelerationPower;
	int _requiredDirectionality;
	CGFloat _defaultHandSize;
	CGFloat _handSizeCompensationPower;
	CGFloat _incrementalMotion;
	CGFloat _smoothedIncrementalMotion;
	CGFloat _cumulativeMotion;
	CGFloat _cumulativeMotionEnvelope;
	CGFloat _cumulativeMotionSkipped;
	BOOL _hasSignificantMotion;
	CGPoint _movementVelocityInPointsPerSecond;
	CGPoint _centroidPoint;
}
@property(readonly, assign, nonatomic) int degreeOfFreedom;
@property(assign, nonatomic) unsigned minTouches;
@property(assign, nonatomic) CGFloat animationDistance;
@property(assign, nonatomic) CGFloat accelerationThreshold;
@property(assign, nonatomic) CGFloat accelerationPower;
@property(assign, nonatomic) int requiredDirectionality;
@property(readonly, assign, nonatomic) CGPoint movementVelocityInPointsPerSecond;
@property(readonly, assign, nonatomic) CGPoint centroidPoint;
@property(readonly, assign, nonatomic) CGFloat incrementalMotion;
@property(readonly, assign, nonatomic) CGFloat cumulativeMotion;
@property(readonly, assign, nonatomic) CGFloat skippedCumulativePercentage;
@property(readonly, assign, nonatomic) CGFloat cumulativePercentage;

- (void)skipCumulativeMotion;
- (CGFloat)computeNonlinearSpeedGain:(CGFloat)gain;
- (CGFloat)computeHandSizeCompensationGain:(CGFloat)gain;
- (void)computeGestureMotion:(SBGestureContextRef)context;
- (CGFloat)computeIncrementalGestureMotion:(SBGestureContextRef)context;
- (void)computeHasSignificantMotionIfNeeded:(SBGestureContextRef)context;
- (void)computeCentroidPoint:(SBGestureContextRef)context;
- (CGFloat)projectMotionForInterval:(NSTimeInterval)interval;
- (int)completionTypeProjectingMomentumForInterval:(NSTimeInterval)interval;
- (void)updateForBeganOrMovedTouches:(SBGestureContextRef)context;
- (void)updateForEndedOrCancelledTouches:(SBGestureContextRef)context;
- (void)updateActiveTouches:(SBGestureContextRef)context;
@end

@interface SBPanGestureRecognizer : SBFluidSlideGestureRecognizer {
	CGFloat _arcCenter;
	CGFloat _arcSize;
	BOOL _recognizesHorizontalPanning;
	BOOL _recognizesVerticalPanning;
}
- (id)initForHorizontalPanning;
- (id)initForVerticalPanning;
@end

@interface SBOffscreenSwipeGestureRecognizer : SBPanGestureRecognizer {
	int m_offscreenEdge;
	CGFloat m_edgeMargin;
	CGFloat m_falseEdge;
	int m_touchesChecked;
	CGPoint m_firstTouch;
	CGFloat m_edgeCenter;
	CGFloat m_allowableDistanceFromEdgeCenter;
	BOOL m_requiresSecondTouchInRange;
}
- (id)initForOffscreenEdge:(int)offscreenEdge;

@property(assign, nonatomic) CGFloat edgeMargin;
@property(assign, nonatomic) CGFloat falseEdge;
@property(assign, nonatomic) CGFloat allowableDistanceFromEdgeCenter;
@property(assign, nonatomic) BOOL requiresSecondTouchInRange;
@property(assign, nonatomic) CGFloat edgeCenter;

- (BOOL)firstTouchInRange:(CGPoint)touchPoint;
- (BOOL)secondTouchInRange:(CGPoint)touchPoint;
- (void)_updateAnimationDistanceAndEdgeCenter;
@end
