//
//  ViewController.h
//  WLXBluetoothDeviceMockPeripheral
//
//  Created by Guido Marucci Blas on 11/13/14.
//  Copyright (c) 2014 Wolox. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UIButton *advertiseButton;

- (IBAction)advertise:(id)sender;

@end

