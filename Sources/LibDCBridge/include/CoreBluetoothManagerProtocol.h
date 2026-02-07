#ifndef CoreBluetoothManagerProtocol_h
#define CoreBluetoothManagerProtocol_h

#ifdef __OBJC__
#import <Foundation/Foundation.h>

@protocol CoreBluetoothManagerProtocol <NSObject>
- (BOOL)connectToDevice:(NSString *)address;
- (BOOL)getPeripheralReadyState;
- (BOOL)discoverServices;
- (BOOL)enableNotifications;
- (BOOL)writeData:(NSData *)data;
- (NSData *)readDataPartial:(int)requested;
- (void)close;
@end

// Inject a BLE manager instance for the bridge layer to use.
// Must be called before any libdivecomputer device operations.
void setBLEManager(id<CoreBluetoothManagerProtocol> manager);

#else
typedef void * CoreBluetoothManagerProtocol;
#endif

#endif /* CoreBluetoothManagerProtocol_h */ 