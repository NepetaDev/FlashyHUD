#import <Cephei/HBPreferences.h>
#import <libcolorpicker.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Tweak.h"

HBPreferences *preferences;

BOOL dpkgInvalid = false;
BOOL enabled = true;
BOOL disableAnimations = false;
BOOL hasShadow = true;
BOOL backgroundShadow = true;
BOOL knobShadow = true;
BOOL inverted = false;
BOOL gradient = false;
BOOL background = true;
BOOL knob = false;
BOOL hapticFeedback = true;
BOOL enableOnLockscreen = false;
BOOL touchControls = false;
NSInteger location = 0; // 0: top; 1: right; 2: bottom; 3: left
CGFloat thickness = 5;
CGFloat knobThickness = 12;
CGFloat knobCornerRadius = 0;
CGFloat size = 1.0;
CGFloat offset = 0;
CGFloat horizontalOffset = 0;
CGFloat verticalOffset = 0;
CGFloat cornerRadius = 0;
CGFloat opacity = 1.0;
CGFloat backgroundPadding = 0;
CGFloat backgroundCornerRadius = 0;
BOOL backgroundCornerRadiusEnabled = false;
UIColor *mediaColor = nil;
UIColor *ringerColor = nil;
UIColor *gradientColor = nil;
UIColor *backgroundColor = nil;

BOOL tempDisableAnimations = false;
BOOL preventAddingDelay = false;
BOOL fadingOrHidden = false;
BOOL preventOut = false;
UIView *lastHUD = nil;
double hideDelay = 0.5;
float lastProgress = -1.0;

@implementation FLHGradientLayer

- (id<CAAction>)actionForKey:(NSString *)event {
    if (disableAnimations || tempDisableAnimations) return nil;
    return [super actionForKey:event];
}

@end

CGRect getFrameForProgress(float progress, CGRect bounds, CGFloat padding) {
    CGFloat fullLength = 0;
    CGFloat x = bounds.size.width * horizontalOffset;
    CGFloat y = bounds.size.height * verticalOffset;

    switch (location) {
        case 1:
        case 3:
            fullLength = bounds.size.height;
            break;
        default:
            fullLength = bounds.size.width;
            break;
    }


    CGFloat length = fullLength * size + padding * 2.0;
    CGFloat width = thickness + padding * 2.0;
    CGFloat sizeOffset = (fullLength - length) / 2.0;

    if (inverted) {
        switch (location) {
            case 0: //top
                return CGRectMake(x + length + sizeOffset - length * progress,
                                y + offset - padding,
                                length * progress,
                                width);
            case 1: //right
                return CGRectMake(x + bounds.size.width - width - offset + padding,
                                y + sizeOffset,
                                width,
                                length * progress);
            case 2: //bottom
                return CGRectMake(x + length + sizeOffset - length * progress,
                                y + bounds.size.height - width - offset + padding,
                                length * progress,
                                width);
            default: //left
                return CGRectMake(x + offset - padding,
                                y + sizeOffset,
                                width,
                                length * progress);
        }
    }

    switch (location) {
        case 0: //top
            return CGRectMake(x + sizeOffset,
                            y + offset - padding,
                            length * progress,
                            width);
        case 1: //right
            return CGRectMake(x + bounds.size.width - width - offset + padding,
                            y + length + sizeOffset - length * progress,
                            width,
                            length * progress);
        case 2: //bottom
            return CGRectMake(x + sizeOffset,
                            y + bounds.size.height - width - offset + padding,
                            length * progress,
                            width);
        default: //left
            return CGRectMake(x + offset - padding,
                            y + length + sizeOffset - length * progress,
                            width,
                            length * progress);
    }
}

CGPoint getBarTip(float progress, CGRect bounds) {
    CGRect frame = getFrameForProgress(progress, bounds, 0);

    if (inverted) {
        switch (location) {
            case 0: //top
                return CGPointMake(frame.origin.x, frame.origin.y + frame.size.height/2.0);
            case 1: //right
                return CGPointMake(frame.origin.x + frame.size.width/2.0, frame.origin.y + frame.size.height);
            case 2: //bottom
                return CGPointMake(frame.origin.x, frame.origin.y + frame.size.height/2.0);
            default: //left
                return CGPointMake(frame.origin.x + frame.size.width/2.0, frame.origin.y + frame.size.height);
        }
    }

    switch (location) {
        case 0: //top
            return CGPointMake(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height/2.0);
        case 1: //right
            return CGPointMake(frame.origin.x + frame.size.width/2.0, frame.origin.y);
        case 2: //bottom
            return CGPointMake(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height/2.0);
        default: //left
            return CGPointMake(frame.origin.x + frame.size.width/2.0, frame.origin.y);
    }
}

CGRect getKnobFrame(float progress, CGRect bounds) {
    CGPoint tip = getBarTip(progress, bounds);
    return CGRectMake(tip.x - knobThickness/2.0, tip.y - knobThickness/2.0, knobThickness, knobThickness);
}

CGSize getShadowOffset(CGFloat padding) {
    CGFloat width = thickness + padding * 2.0;
    switch (location) {
        case 0: //top
            return CGSizeMake(0, width/2.0);
        case 1: //right
            return CGSizeMake(-width/2.0, 0);
        case 2: //bottom
            return CGSizeMake(0, -width/2.0);
        default: //left
            return CGSizeMake(width/2.0, 0);
    }
}

CGPoint getStartPoint() {
    switch (location) {
        case 0: //top
            return CGPointMake(0.0, 0.5);
        case 1: //right
            return CGPointMake(0.5, 1.0);
        case 2: //bottom
            return CGPointMake(0.0, 0.5);
        default: //left
            return CGPointMake(0.5, 1.0);
    }
}

CGPoint getEndPoint() {
    switch (location) {
        case 0: //top
            return CGPointMake(1.0, 0.5);
        case 1: //right
            return CGPointMake(0.5, 0.0);
        case 2: //bottom
            return CGPointMake(1.0, 0.5);
        default: //left
            return CGPointMake(0.5, 0.0);
    }
}

%group FlashyHUD

%hook SBHUDController

-(void)_tearDown {
    if (!preventOut) %orig;
    preventOut = false;
}

-(void)hideHUDView {
    fadingOrHidden = true;
    if (disableAnimations) [lastHUD setAlpha:0.01];
    lastProgress = -1.0;
    %orig;
}

-(void)presentHUDView:(id)arg1 autoDismissWithDelay:(double)arg2 {
    %orig(arg1, -1.0); //-1.0 = stops it from dismissing
    fadingOrHidden = false;
    
    if (preventAddingDelay) return;
    [NSObject cancelPreviousPerformRequestsWithTarget:[%c(SBHUDController) sharedHUDController] selector:@selector(hideHUDView) object:[%c(SBHUDController) sharedHUDController]];
    [[%c(SBHUDController) sharedHUDController] performSelector:@selector(hideHUDView) withObject:[%c(SBHUDController) sharedHUDController] afterDelay:hideDelay];
}

%end

%hook SBHUDView

%property (nonatomic, retain) FLHGradientLayer *flhLayer;
%property (nonatomic, retain) FLHGradientLayer *flhBackgroundLayer;
%property (nonatomic, retain) FLHGradientLayer *flhKnobLayer;
%property (nonatomic, assign) CGRect flhFullFrame;

%new
-(float)flhRealProgress {
    if ([self respondsToSelector:@selector(isSilent)] && [((SBRingerHUDView *)self) isSilent]) {
        return 0.0;
    }

    return self.progress;
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!touchControls) {
        %orig;
        return;
    }

    if ([self isKindOfClass:%c(SBRingerHUDView)] || ([self respondsToSelector:@selector(mode)] && [((SBVolumeHUDView *)self) mode] == 1)) {
        %orig;
        return;
    }

    tempDisableAnimations = true;

    [NSObject cancelPreviousPerformRequestsWithTarget:[%c(SBHUDController) sharedHUDController] selector:@selector(hideHUDView) object:[%c(SBHUDController) sharedHUDController]];
    
    CGPoint point = [[touches anyObject] locationInView:self];
    BOOL vertical = (location == 1 || location == 3);
    BOOL endIsMax = (vertical == inverted);
    
    float newProgress = 0;
    CGFloat length = 0;
    CGFloat rpl = 0;

    if (vertical) {
        length = self.flhFullFrame.size.height;
        rpl = self.flhFullFrame.origin.y - point.y;
    } else {
        length = self.flhFullFrame.size.width;
        rpl = self.flhFullFrame.origin.x - point.x;
    }

    rpl += length;

    if (rpl < 0) rpl = 0;
    if (rpl > length) rpl = length;

    newProgress = (float) (rpl/length);
    if (endIsMax) newProgress = 1 - newProgress;

    [self setProgress:newProgress];
    preventAddingDelay = true;

    if (fadingOrHidden) {
        preventOut = true;
        [[%c(VolumeControl) sharedVolumeControl] setMediaVolume:self.progress];
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (fadingOrHidden) {
        preventOut = false;
    }
    [[%c(VolumeControl) sharedVolumeControl] setMediaVolume:self.progress];
    [NSObject cancelPreviousPerformRequestsWithTarget:[%c(SBHUDController) sharedHUDController] selector:@selector(hideHUDView) object:[%c(SBHUDController) sharedHUDController]];
    [[%c(SBHUDController) sharedHUDController] performSelector:@selector(hideHUDView) withObject:[%c(SBHUDController) sharedHUDController] afterDelay:hideDelay];

    preventAddingDelay = false;
    tempDisableAnimations = false;
}

-(void)layoutSubviews {
    %orig;

    lastHUD = self;

    UIColor *color = mediaColor;
    if ([self isKindOfClass:%c(SBRingerHUDView)] || ([self respondsToSelector:@selector(mode)] && [((SBVolumeHUDView *)self) mode] == 1)) {
        color = ringerColor;
    }

    CGRect bounds = [[UIScreen mainScreen] bounds];
    self.frame = bounds;
    self.alpha = opacity;
    self.flhFullFrame = getFrameForProgress(1.0, bounds, 0.0);

    if (!self.flhBackgroundLayer) {
        self.layer.sublayers = nil;
        self.layer.masksToBounds = NO;
        self.flhBackgroundLayer = [[FLHGradientLayer alloc] init];
        self.flhBackgroundLayer.masksToBounds = NO;
 
        [self.layer addSublayer:self.flhBackgroundLayer];
    }

    if (!self.flhLayer) {
        self.flhLayer = [[FLHGradientLayer alloc] init];
        self.flhLayer.masksToBounds = NO;
 
        [self.layer addSublayer:self.flhLayer];
    }

    if (!self.flhKnobLayer) {
        self.flhKnobLayer = [[FLHGradientLayer alloc] init];
        self.flhKnobLayer.masksToBounds = NO;
 
        [self.layer addSublayer:self.flhKnobLayer];
    }

    self.flhBackgroundLayer.frame = getFrameForProgress(1.0, bounds, backgroundPadding);
    if (background) {
        self.flhBackgroundLayer.backgroundColor = backgroundColor.CGColor;
    } else {
        self.flhBackgroundLayer.backgroundColor = [UIColor clearColor].CGColor;
    }

    self.flhLayer.backgroundColor = color.CGColor;

    self.flhLayer.frame = getFrameForProgress([self flhRealProgress], bounds, 0.0);
    self.flhLayer.startPoint = getStartPoint();
    self.flhLayer.endPoint = getEndPoint();

    self.flhLayer.cornerRadius = cornerRadius;
    self.flhBackgroundLayer.cornerRadius = (backgroundCornerRadiusEnabled) ? backgroundCornerRadius : cornerRadius;

    if (knob) {
        self.flhKnobLayer.backgroundColor = color.CGColor;
    } else {
        self.flhKnobLayer.backgroundColor = [UIColor clearColor].CGColor;
    }
    self.flhKnobLayer.frame = getKnobFrame([self flhRealProgress], bounds);
    self.flhKnobLayer.cornerRadius = knobCornerRadius; //TODO

    if (hasShadow) {
        self.flhLayer.shadowOpacity = 0.5;
        self.flhLayer.shadowRadius = thickness;
        self.flhLayer.shadowColor = color.CGColor;
        self.flhLayer.shadowOffset = getShadowOffset(0.0);
    } else {
        self.flhLayer.shadowOpacity = 0;
    }

    if (backgroundShadow) {
        self.flhBackgroundLayer.shadowOpacity = 0.5;
        self.flhBackgroundLayer.shadowRadius = thickness;
        self.flhBackgroundLayer.shadowColor = backgroundColor.CGColor;
        self.flhBackgroundLayer.shadowOffset = getShadowOffset(backgroundPadding);
    } else {
        self.flhBackgroundLayer.shadowOpacity = 0;
    }

    if (knobShadow) {
        self.flhKnobLayer.shadowOpacity = 0.5;
        self.flhKnobLayer.shadowRadius = knobThickness;
        self.flhKnobLayer.shadowColor = backgroundColor.CGColor;
        self.flhKnobLayer.shadowOffset = CGSizeMake(knobThickness/2.0, knobThickness/2.0);
    } else {
        self.flhKnobLayer.shadowOpacity = 0;
    }

    if (gradient) {
        self.flhLayer.colors = @[(id)color.CGColor, (id)gradientColor.CGColor];
    } else {
        self.flhLayer.colors = nil;
    }
}

-(void)addSubview:(id)xxx {
    //noop
}

-(void)insertSubview:(id)xxx atIndex:(int)x {
    //noop
}

-(void)setProgress:(float)arg1 {
    %orig;

    float progress = [self flhRealProgress];
    if (hapticFeedback && (progress == 0.0 || progress == 1.0) && lastProgress != progress) AudioServicesPlaySystemSound(1519);
    lastProgress = progress;
}

%end

%hook SBHUDWindow

-(BOOL)_ignoresHitTest {
    if (touchControls) return NO;
    return %orig;
}

-(void)setHidden:(BOOL)hidden {
    if (hidden == self.hidden) return;
    %orig;
    
    if (hidden) return;

    if (disableAnimations) {
        self.alpha = 1.0;
        return;
    }
    
    self.alpha = 0.0;
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.alpha = 1.0;
    } completion:nil];
}

-(id)hitTest:(CGPoint)arg1 withEvent:(id)arg2 {
    if (!touchControls) return nil;

    if (CGRectContainsPoint([(SBHUDView*)lastHUD flhBackgroundLayer].frame, arg1)) {
        return lastHUD;
    }

    return nil;
}

%end

%hook MPVolumeSlider

- (bool)isOnScreenForVolumeDisplay {
    if (enabled && enableOnLockscreen) return false;
    return %orig;
}

%end

%hook VolumeControl

-(BOOL)_isMusicPlayingSomewhere {
    if (enabled && enableOnLockscreen) return true;
    return %orig;
}

%end

%end

%group FlashyHUDIntegrityFail

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
    if (!dpkgInvalid) return;
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"😡😡😡"
        message:@"The build of FlashyHUD you're using comes from an untrusted source. Pirate repositories can distribute malware and you will get subpar user experience using any tweaks from them.\nRemember: FlashyHUD is free. Uninstall this build and install the proper version of FlashyHUD from:\nhttps://repo.nepeta.me/\n(it's free, damnit, why would you pirate that!?)"
        preferredStyle:UIAlertControllerStyleAlert
    ];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Damn!" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [((UIApplication*)self).keyWindow.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }]];

    [((UIApplication*)self).keyWindow.rootViewController presentViewController:alertController animated:YES completion:NULL];
}

%end

%end

void refreshHUD() {
    [CATransaction begin];
    [CATransaction setDisableActions: YES];
    [lastHUD layoutSubviews];
    [CATransaction commit];
}

void reloadColors() {
    NSDictionary *colors = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nepeta.flashyhud-colors.plist"];
    if (!colors) return;

    mediaColor = [LCPParseColorString([colors objectForKey:@"MediaColor"], @"#ffffff:1.0") copy];
    ringerColor = [LCPParseColorString([colors objectForKey:@"RingerColor"], @"#ffffff:1.0") copy];
    gradientColor = [LCPParseColorString([colors objectForKey:@"GradientColor"], @"#000000:1.0") copy];
    backgroundColor = [LCPParseColorString([colors objectForKey:@"BackgroundColor"], @"#000000:1.0") copy];
    refreshHUD();
}

%ctor {
    dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.flashyhud.list"];

    if (dpkgInvalid) {
        %init(FlashyHUDIntegrityFail);
        return;
    }

    preferences = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.flashyhud"];

    [preferences registerBool:&enabled default:YES forKey:@"Enabled"];
    [preferences registerBool:&hasShadow default:YES forKey:@"HasShadow"];
    [preferences registerBool:&backgroundShadow default:YES forKey:@"BackgroundShadow"];
    [preferences registerBool:&background default:YES forKey:@"Background"];
    [preferences registerBool:&backgroundCornerRadiusEnabled default:NO forKey:@"BackgroundCornerRadiusEnabled"];
    [preferences registerBool:&inverted default:NO forKey:@"Inverted"];
    [preferences registerBool:&gradient default:NO forKey:@"Gradient"];
    [preferences registerInteger:&location default:0 forKey:@"Location"];
    [preferences registerFloat:&thickness default:5.0 forKey:@"Thickness"];
    [preferences registerFloat:&size default:1.0 forKey:@"Size"];
    [preferences registerFloat:&offset default:0.0 forKey:@"Offset"];
    [preferences registerFloat:&horizontalOffset default:0.0 forKey:@"HorizontalOffset"];
    [preferences registerFloat:&verticalOffset default:0.0 forKey:@"VerticalOffset"];
    [preferences registerFloat:&cornerRadius default:0.0 forKey:@"CornerRadius"];
    [preferences registerFloat:&backgroundCornerRadius default:0.0 forKey:@"BackgroundCornerRadius"];
    [preferences registerFloat:&backgroundPadding default:0.0 forKey:@"BackgroundPadding"];
    [preferences registerFloat:&opacity default:1.0 forKey:@"Opacity"];

    [preferences registerBool:&knob default:NO forKey:@"Knob"];
    [preferences registerBool:&knobShadow default:YES forKey:@"KnobShadow"];
    [preferences registerFloat:&knobThickness default:12.0 forKey:@"KnobThickness"];
    [preferences registerFloat:&knobCornerRadius default:0.0 forKey:@"KnobCornerRadius"];

    [preferences registerBool:&touchControls default:NO forKey:@"TouchControls"];
    [preferences registerBool:&disableAnimations default:NO forKey:@"DisableAnimations"];
    [preferences registerBool:&hapticFeedback default:YES forKey:@"HapticFeedback"];
    [preferences registerBool:&enableOnLockscreen default:NO forKey:@"EnableOnLockscreen"];

    mediaColor = [UIColor whiteColor];
    ringerColor = [UIColor whiteColor];
    gradientColor = [UIColor blackColor];
    backgroundColor = [UIColor blackColor];

    reloadColors();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadColors, (CFStringRef)@"me.nepeta.flashyhud/ReloadColors", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshHUD, (CFStringRef)@"me.nepeta.flashyhud/ReloadPrefs", NULL, (CFNotificationSuspensionBehavior)kNilOptions);

    %init(FlashyHUD);
}
