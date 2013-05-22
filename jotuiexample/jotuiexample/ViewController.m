//
//  ViewController.m
//  jotuiexample
//
//  Created by Adam Wulf on 12/8/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "ViewController.h"
#import <JotUI/JotUI.h>
#import <JotTouchSDK/JotStylusManager.h>

@interface ViewController(){
    JotStylusManager* jotManager;
    
}

@end


@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    pen = [[Pen alloc] init];
    marker = [[Marker alloc] init];
    eraser = [[Eraser alloc] init];
    
    
    jotManager = [JotStylusManager sharedInstance];
    
    [jotManager addShortcutOptionButton1Default: [[JotShortcut alloc]
                                                  initWithShortDescription:@"Next Color"
                                                  key:@"nc"
                                                  target:self selector:@selector(nextColor)]];
    
    
    [jotManager addShortcutOptionButton2Default: [[JotShortcut alloc]
                                                  initWithShortDescription:@"Previous Color"
                                                  key:@"pc"
                                                  target:self selector:@selector(previousColor)]];
    
    [jotManager addShortcutOption: [[JotShortcut alloc]
                                    initWithShortDescription:@"Increase Stroke Width"
                                    key:@"isw"
                                    target:self selector:@selector(increaseStrokeWidth)
                                    repeatRate:100]];
    
    [jotManager addShortcutOption: [[JotShortcut alloc]
                                    initWithShortDescription:@"Decrease Stroke Width"
                                    key:@"dsw"
                                    target:self selector:@selector(decreaseStrokeWidth)
                                    repeatRate:100]];
        
    [jotManager addShortcutOption: [[JotShortcut alloc]
                                    initWithShortDescription:@"Undo"
                                    key:@"undo"
                                    target:self selector:@selector(undo)
                                    repeatRate:100]];
    
    [jotManager addShortcutOption: [[JotShortcut alloc]
                                    initWithShortDescription:@"Redo"
                                    key:@"redo"
                                    target:self selector:@selector(redo)
                                    repeatRate:100]];
    
    
    jotManager.unconnectedPressure = 0;
    jotManager.palmRejectorDelegate = jotView;
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector:@selector(connectionChange:)
                                                 name: JotStylusManagerDidChangeConnectionStatus
                                               object:nil];
    
    jotManager.rejectMode = NO;
    jotManager.enabled = YES;
    
    
    
    [self changePenType:nil];
    
    [self tappedColorButton:blackButton];
    
    marker.color = [redButton backgroundColor];
    pen.color = [blackButton backgroundColor];
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - Helpers

-(Pen*) activePen{
    if(penVsMarkerControl.selectedSegmentIndex == 0){
        return pen;
    }else if(penVsMarkerControl.selectedSegmentIndex == 1){
        return marker;
    }else{
        return eraser;
    }
}

-(void) updatePenTickers{
    minAlpha.text = [NSString stringWithFormat:@"%.2f", [self activePen].minAlpha];
    maxAlpha.text = [NSString stringWithFormat:@"%.2f", [self activePen].maxAlpha];
    minWidth.text = [NSString stringWithFormat:@"%d", (int)[self activePen].minSize];
    maxWidth.text = [NSString stringWithFormat:@"%d", (int)[self activePen].maxSize];
}



#pragma mark - IBAction


-(IBAction)togglePalmRejection{
    palmRejectionButton.selected = !palmRejectionButton.selected;
    jotManager.rejectMode = palmRejectionButton.selected;
}

-(IBAction) changePenType:(id)sender{
    [jotView setBrushTexture:[self activePen].texture];

    if([[self activePen].color isEqual:blackButton.backgroundColor]) [self tappedColorButton:blackButton];
    if([[self activePen].color isEqual:redButton.backgroundColor]) [self tappedColorButton:redButton];
    if([[self activePen].color isEqual:greenButton.backgroundColor]) [self tappedColorButton:greenButton];
    if([[self activePen].color isEqual:blueButton.backgroundColor]) [self tappedColorButton:blueButton];

    [self updatePenTickers];
}

-(IBAction) toggleOptionsPane:(id)sender{
    additionalOptionsView.hidden = !additionalOptionsView.hidden;
}

-(IBAction) tappedColorButton:(UIButton*) sender{
    for(UIButton* button in [NSArray arrayWithObjects:blueButton, redButton, greenButton, blackButton, nil]){
        if(sender == button){
            [button setBackgroundImage:[UIImage imageNamed:@"check.png"] forState:UIControlStateNormal];
            button.selected = YES;
        }else{
            [button setBackgroundImage:nil forState:UIControlStateNormal];
            button.selected = NO;
        }
    }
    
    [self activePen].color = [sender backgroundColor];
}

-(IBAction) changeWidthOrSize:(UISegmentedControl*)sender{
    if(sender == minAlphaDelta){
        if(sender.selectedSegmentIndex == 0){
            [self activePen].minAlpha -= .1;
        }else if(sender.selectedSegmentIndex == 1){
            [self activePen].minAlpha -= .01;
        }else if(sender.selectedSegmentIndex == 2){
            [self activePen].minAlpha += .01;
        }else if(sender.selectedSegmentIndex == 3){
            [self activePen].minAlpha += .1;
        }
    }
    if(sender == maxAlphaDelta){
        if(sender.selectedSegmentIndex == 0){
            [self activePen].maxAlpha -= .1;
        }else if(sender.selectedSegmentIndex == 1){
            [self activePen].maxAlpha -= .01;
        }else if(sender.selectedSegmentIndex == 2){
            [self activePen].maxAlpha += .01;
        }else if(sender.selectedSegmentIndex == 3){
            [self activePen].maxAlpha += .1;
        }
    }
    if(sender == minWidthDelta){
        if(sender.selectedSegmentIndex == 0){
            [self activePen].minSize -= 5;
        }else if(sender.selectedSegmentIndex == 1){
            [self activePen].minSize -= 1;
        }else if(sender.selectedSegmentIndex == 2){
            [self activePen].minSize += 1;
        }else if(sender.selectedSegmentIndex == 3){
            [self activePen].minSize += 5;
        }
    }
    if(sender == maxWidthDelta){
        if(sender.selectedSegmentIndex == 0){
            [self activePen].maxSize -= 5;
        }else if(sender.selectedSegmentIndex == 1){
            [self activePen].maxSize -= 1;
        }else if(sender.selectedSegmentIndex == 2){
            [self activePen].maxSize += 1;
        }else if(sender.selectedSegmentIndex == 3){
            [self activePen].maxSize += 5;
        }
    }
    
    
    if([self activePen].minAlpha < 0) [self activePen].minAlpha = 0;
    if([self activePen].minAlpha > 1) [self activePen].minAlpha = 1;

    if([self activePen].maxAlpha < 0) [self activePen].maxAlpha = 0;
    if([self activePen].maxAlpha > 1) [self activePen].maxAlpha = 1;
    
    if([self activePen].minSize < 0) [self activePen].minSize = 0;
    if([self activePen].maxSize < 0) [self activePen].maxSize = 0;
    
    [self updatePenTickers];
}


-(IBAction) saveImage{
    [jotView exportToImageWithBackgroundColor:nil andBackgroundImage:nil onComplete:^(UIImage* image){
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }];
}

-(IBAction) loadImageFromLibary:(UIButton*)sender{
    if(popoverController){
        [popoverController dismissPopoverAnimated:NO];
        popoverController = nil;
    }
    UIImagePickerController *pickerLibrary = [[UIImagePickerController alloc] init];
    pickerLibrary.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerLibrary.delegate = self;
    popoverController = [[UIPopoverController alloc] initWithContentViewController:pickerLibrary];
    popoverController.delegate = self;
    [popoverController presentPopoverFromRect:sender.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
}
- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    [jotView loadImage:image];
    [popoverController dismissPopoverAnimated:YES];
    popoverController = nil;
}


-(IBAction) showSettings:(id)sender{
    JotSettingsViewController* settings = [[JotSettingsViewController alloc] initWithOnOffSwitch:YES andShowPalmRejection:YES];
    if(popoverController){
        [popoverController dismissPopoverAnimated:NO];
    }
    popoverController = [[UIPopoverController alloc] initWithContentViewController:settings];
    [popoverController presentPopoverFromRect:[sender frame] inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    [popoverController setPopoverContentSize:CGSizeMake(300, 400) animated:NO];
}

#pragma mark - Jot Stylus Button Callbacks

-(void)nextColor{
    // double the blue button, so that if the black is selected,
    // we'll cycle back to the beginning
    NSArray* buttons = [NSArray arrayWithObjects:blackButton, redButton, greenButton, blueButton, blackButton, nil];
    for(UIButton* button in buttons){
        if(button.selected){
            [self tappedColorButton:[buttons objectAtIndex:[buttons indexOfObject:button inRange:NSMakeRange(0, [buttons count]-1)]+1]];
            break;
        }
    }
}
-(void)previousColor{
    NSArray* buttons = [NSArray arrayWithObjects:blueButton, greenButton, redButton, blackButton, blueButton, nil];
    for(UIButton* button in buttons){
        if(button.selected){
            [self tappedColorButton:[buttons objectAtIndex:[buttons indexOfObject:button inRange:NSMakeRange(0, [buttons count]-1)]+1]];
            break;
        }
    }
}

-(void)increaseStrokeWidth{
    [self activePen].minSize += 1;
    [self activePen].maxSize += 1.5;
    [self updatePenTickers];
}
-(void)decreaseStrokeWidth{
    [self activePen].minSize -= 1;
    [self activePen].maxSize -= 1.5;
    [self updatePenTickers];
}

-(void) undo{
    [jotView undo];
}

-(void) redo{
    [jotView redo];
}


#pragma mark - JotViewDelegate

-(void) willBeginStrokeWithTouch:(JotTouch*)touch{
    [[self activePen] willBeginStrokeWithTouch:touch];
}

-(void) willMoveStrokeWithTouch:(JotTouch*)touch{
    [[self activePen] willMoveStrokeWithTouch:touch];
}

-(void) didEndStrokeWithTouch:(JotTouch*)touch{
    [[self activePen] didEndStrokeWithTouch:touch];
}

-(void) didCancelStrokeWithTouch:(JotTouch*)touch{
    [[self activePen] didCancelStrokeWithTouch:touch];
}

-(UIColor*) colorForTouch:(JotTouch *)touch{
    [[self activePen] setShouldUseVelocity:pressureVsVelocityControl.selectedSegmentIndex];
    return [[self activePen] colorForTouch:touch];
}

-(CGFloat) widthForTouch:(JotTouch*)touch{
    [[self activePen] setShouldUseVelocity:pressureVsVelocityControl.selectedSegmentIndex];
    return [[self activePen] widthForTouch:touch];
}
-(CGFloat) smoothnessForTouch:(JotTouch *)touch{
    return [[self activePen] smoothnessForTouch:touch];
}

-(CGFloat) rotationForSegment:(AbstractBezierPathElement *)segment fromPreviousSegment:(AbstractBezierPathElement *)previousSegment{
    return [[self activePen] rotationForSegment:segment fromPreviousSegment:previousSegment];
}

#pragma mark - StylusConnectionDelegate

-(void)connectionChange:(NSNotification *) note{
    NSString *text;
    switch([[JotStylusManager sharedInstance] connectionStatus])
    {
        case JotConnectionStatusOff:
            text = @"Off";
            break;
        case JotConnectionStatusScanning:
            text = @"Scanning";
            break;
        case JotConnectionStatusPairing:
            text = @"Pairing";
            break;
        case JotConnectionStatusConnected:
            text = @"Connected";
            break;
        case JotConnectionStatusDisconnected:
            text = @"Disconnected";
            break;
        default:
            text = @"";
            break;
    }
    [settingsButton setTitle: text forState:UIControlStateNormal];
}

#pragma mark - UIPopoverControllerDelegate

-(void) popoverControllerDidDismissPopover:(UIPopoverController *)_popoverController{
    popoverController = nil;
}

@end
