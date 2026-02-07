#import "BLEBridge.h"
#import <Foundation/Foundation.h>

static id<CoreBluetoothManagerProtocol> bleManager = nil;

void setBLEManager(id<CoreBluetoothManagerProtocol> manager) {
    bleManager = manager;
}

void initializeBLEManager(void) {
    // No-op: manager is now injected via setBLEManager().
    // Kept for C bridge compatibility (called by configuredc.c).
}

ble_object_t* createBLEObject(void) {
    if (!bleManager) {
        NSLog(@"BLEBridge: No BLE manager has been injected. Call setBLEManager() first.");
        return NULL;
    }
    ble_object_t* obj = malloc(sizeof(ble_object_t));
    obj->manager = (__bridge void *)bleManager;
    return obj;
}

void freeBLEObject(ble_object_t* obj) {
    if (obj) {
        free(obj);
    }
}

bool connectToBLEDevice(ble_object_t *io, const char *deviceAddress) {
    if (!io || !deviceAddress || !bleManager) {
        NSLog(@"BLEBridge: Invalid parameters or no manager injected");
        return false;
    }

    NSString *address = [NSString stringWithUTF8String:deviceAddress];

    bool success = [bleManager connectToDevice:address];
    if (!success) {
        NSLog(@"BLEBridge: Failed to connect to device");
        return false;
    }
    
    // Wait for connection to complete by checking peripheral ready state
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:10.0];
    while ([[NSDate date] compare:timeout] == NSOrderedAscending) {
        if ([bleManager getPeripheralReadyState]) {
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }

    if (![bleManager getPeripheralReadyState]) {
        NSLog(@"BLEBridge: Timeout waiting for peripheral to be ready");
        [bleManager close];
        return false;
    }

    success = [bleManager discoverServices];
    if (!success) {
        NSLog(@"BLEBridge: Service discovery failed");
        [bleManager close];
        return false;
    }

    success = [bleManager enableNotifications];
    if (!success) {
        NSLog(@"BLEBridge: Failed to enable notifications");
        [bleManager close];
        return false;
    }
    
    return true;
}

bool discoverServices(ble_object_t *io) {
    if (!bleManager) return false;
    return [bleManager discoverServices];
}

bool enableNotifications(ble_object_t *io) {
    if (!bleManager) return false;
    return [bleManager enableNotifications];
}

dc_status_t ble_set_timeout(ble_object_t *io, int timeout) {
    return DC_STATUS_SUCCESS;
}

dc_status_t ble_ioctl(ble_object_t *io, unsigned int request, void *data, size_t size) {
    return DC_STATUS_UNSUPPORTED;
}

dc_status_t ble_sleep(ble_object_t *io, unsigned int milliseconds) {
    [NSThread sleepForTimeInterval:milliseconds / 1000.0];
    return DC_STATUS_SUCCESS;
}

dc_status_t ble_read(ble_object_t *io, void *buffer, size_t requested, size_t *actual)
{
    if (!io || !buffer || !actual || !bleManager) {
        return DC_STATUS_INVALIDARGS;
    }

    NSData *partialData = [bleManager readDataPartial:(int)requested];

    if (!partialData || partialData.length == 0) {
        *actual = 0;
        return DC_STATUS_IO;
    }
    memcpy(buffer, partialData.bytes, partialData.length);
    *actual = partialData.length;
    return DC_STATUS_SUCCESS;
}

dc_status_t ble_write(ble_object_t *io, const void *data, size_t size, size_t *actual) {
    if (!bleManager) {
        *actual = 0;
        return DC_STATUS_IO;
    }
    NSData *nsData = [NSData dataWithBytes:data length:size];

    if ([bleManager writeData:nsData]) {
        *actual = size;
        return DC_STATUS_SUCCESS;
    } else {
        *actual = 0;
        return DC_STATUS_IO;
    }
}

dc_status_t ble_close(ble_object_t *io) {
    if (!bleManager) return DC_STATUS_SUCCESS;
    [bleManager close];
    return DC_STATUS_SUCCESS;
}
