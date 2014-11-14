//
//  ViewController.m
//  WLXBluetoothDeviceMockPeripheral
//
//  Created by Guido Marucci Blas on 11/13/14.
//  Copyright (c) 2014 Wolox. All rights reserved.
//

#import "ViewController.h"

@import CoreBluetooth;

@interface ViewController ()<CBPeripheralManagerDelegate>

@property (nonatomic) BOOL canAdvertise;
@property (nonatomic) CBPeripheralManager * peripheralManager;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) CBUUID * serviceUUID;
@property (nonatomic) CBUUID * characteristicUUID;
@property (nonatomic) CBMutableCharacteristic * characteristic;
@property (nonatomic) NSMutableArray * buffer;
@property (nonatomic) NSTimer * timer;
@property (nonatomic) CBMutableService * service;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.logTextView.text = @"";
    self.canAdvertise = YES;
    self.queue = dispatch_queue_create("ar.com.wolox.WLXBluetoothDevice.MockPeripheral", 0);
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.queue];
    self.serviceUUID = [CBUUID UUIDWithString:@"68753A44-4D6F-1226-9C60-0050E4C00066"];
    self.characteristicUUID = [CBUUID UUIDWithString:@"68753A44-4D6F-1226-9C60-0050E4C00067"];
    self.characteristic = [[CBMutableCharacteristic alloc] initWithType:self.characteristicUUID
                                                             properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify
                                                                  value:nil
                                                            permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
    [self.advertiseButton setTitle:@"Advertise" forState:UIControlStateNormal];
    self.service = [[CBMutableService alloc] initWithType:self.serviceUUID primary:YES];
    self.service.characteristics = @[self.characteristic];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)advertise:(id)sender {
    if (self.canAdvertise) {
        self.canAdvertise = NO;
        [self logMessage:@"Advertising peripheral ..."];
        [self advertisePeripheral];
        [self.advertiseButton setTitle:@"Stop advertising" forState:UIControlStateNormal];
    } else {
        self.canAdvertise = YES;
        [self logMessage:@"Stop advertising peripheral ..."];
        [self.peripheralManager stopAdvertising];
        [self.advertiseButton setTitle:@"Advertise" forState:UIControlStateNormal];
    }
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSString * state = nil;
    switch (peripheral.state) {
        case CBPeripheralManagerStateUnknown:
            state = @"unknown";
            break;
        case CBPeripheralManagerStateResetting:
            state = @"resetting";
            break;
        case CBPeripheralManagerStateUnsupported:
            state = @"unsupported";
            break;
        case CBPeripheralManagerStateUnauthorized:
            state = @"unauthorized";
            break;
        case CBPeripheralManagerStatePoweredOff:
            state = @"off";
            break;
        case CBPeripheralManagerStatePoweredOn:
            state = @"on";
            [self.peripheralManager addService:self.service];
            break;
        default:
            break;
    }
    [self logMessage:@"Peripheral update state to %@", state];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self logMessage:@"Service could not be added: %@", error];
    } else {
        [self logMessage:@"Service %@ successfully added", self.serviceUUID];
        NSUInteger value = 15;
        [self updateCharacteristicWithValue:[NSData dataWithBytes:&value length:sizeof(value)]];
    }
}


- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (error) {
        [self logMessage:@"There was an error advertising the peripheral: %@", error];
        self.canAdvertise = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.advertiseButton setTitle:@"Advertise" forState:UIControlStateNormal];
        });
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    [self logMessage:@"A subscription request has arrived for characteristic %@", characteristic.UUID.UUIDString];
    if ([characteristic.UUID isEqual:self.characteristicUUID]) {
        [self logMessage:@"Starting timer to update characteristic"];
        [self.timer invalidate];
        self.timer = nil;
        [self startTimer];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    [self logMessage:@"An unsubscription request has arrived for characteristic %@", characteristic.UUID.UUIDString];
    if ([characteristic.UUID isEqual:self.characteristicUUID]) {
        [self.timer invalidate];
        self.timer = nil;
        [self logMessage:@"Stoping timer"];
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    [self logMessage:@"Flushing pending updates ..."];
    NSMutableArray * bufferCopy = [self.buffer copy];
    for (NSData * data in bufferCopy) {
        BOOL successfullUpdate = [self.peripheralManager updateValue:data forCharacteristic:self.characteristic onSubscribedCentrals:nil];
        if (successfullUpdate) {
            [self.buffer removeObject:data];
        } else {
            [self logMessage:@"Fail to flush all pending updates"];
            break;
        }
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    [self logMessage:@"A read request has been received"];
    request.value = self.characteristic.value;
    [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
    [self logMessage:@"A write request has been received"];
    [self.peripheralManager respondToRequest:[requests firstObject] withResult:CBATTErrorSuccess];
    for (CBATTRequest * request in requests) {
        if ([request.characteristic.UUID isEqual:self.characteristicUUID]) {
            [self updateCharacteristicWithValue:request.value];
            [self logMessage:@"Characteristic value updated to %ld", (unsigned long)*((NSUInteger *)request.value.bytes)];
        }
    }
}


#pragma mark - Private methods

- (void)startTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateCharacteristic:) userInfo:nil repeats:YES];
    });
}

- (void)publishCharacteristicValueToCentral:(CBCentral *)central {
    [self logMessage:@"Publishing characteristic value"];
    BOOL successfullUpdate = [self.peripheralManager updateValue:self.characteristic.value forCharacteristic:self.characteristic onSubscribedCentrals:@[central]];
    if (!successfullUpdate) {
        [self logMessage:@"Fail to publish value. Saving it for later."];
    }
}

- (void)updateCharacteristicWithValue:(NSData *)data {
    NSUInteger value = *((NSUInteger *)data.bytes);
    self.characteristic.value = data;
    [self logMessage:@"Updating value to %ld", (unsigned long)value];
    BOOL successfullUpdate = [self.peripheralManager updateValue:data forCharacteristic:self.characteristic onSubscribedCentrals:nil];
    if (!successfullUpdate) {
        [self logMessage:@"Fail to update value. Saving it for later."];
    }
}

- (void)updateCharacteristic:(NSTimer *)timer {
    NSUInteger value = *((NSUInteger *)self.characteristic.value.bytes);
    value++;
    NSData * data = [NSData dataWithBytes:&value length:sizeof(value)];
    self.characteristic.value = data;
    [self logMessage:@"Updating value to %ld", (unsigned long)value];
    BOOL successfullUpdate = [self.peripheralManager updateValue:data forCharacteristic:self.characteristic onSubscribedCentrals:nil];
    if (!successfullUpdate) {
        [self logMessage:@"Fail to update value. Saving it for later."];
        [self.buffer addObject:data];
    }
}

- (void)advertisePeripheral {
    NSDictionary * advertismentData = @{
        CBAdvertisementDataLocalNameKey : @"MockPeripheral",
        CBAdvertisementDataServiceUUIDsKey : @[ self.serviceUUID ]
    };
    [self.peripheralManager startAdvertising:advertismentData];
}

- (void)logMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    va_list args;
    va_start(args, format);
    NSString * message = [[NSString alloc] initWithFormat:format arguments:args];
    message = [message stringByAppendingString:@"\n"];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingString:message];
    });
    va_end(args);
}

@end
