/*
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import "UsersDevicesViewController.h"

#import "AppDelegate.h"
#import "Riot-Swift.h"

@interface UsersDevicesViewController () <DeviceVerificationCoordinatorBridgePresenterDelegate>
{
    MXUsersDevicesMap<MXDeviceInfo*> *usersDevices;
    MXSession *mxSession;

    void (^onCompleteBlock)(BOOL doneButtonPressed);

    DeviceVerificationCoordinatorBridgePresenter *deviceVerificationCoordinatorBridgePresenter;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    id kThemeServiceDidChangeThemeNotificationObserver;
}

@end

@implementation UsersDevicesViewController

- (void)displayUsersDevices:(MXUsersDevicesMap<MXDeviceInfo*>*)theUsersDevices andMatrixSession:(MXSession*)matrixSession onComplete:(void (^)(BOOL doneButtonPressed))onComplete
{
    usersDevices = theUsersDevices;
    mxSession = matrixSession;
    onCompleteBlock = onComplete;
}

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"unknown_devices_title", @"Vector", nil);
    self.accessibilityLabel=@"UsersDevicesVCTitleStaticText";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone:)];
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"UsersDevicesVCDoneButton";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
    self.navigationItem.leftBarButtonItem.accessibilityIdentifier=@"UsersDevicesVCCancelButton";
    self.tableView.delegate = self;
    self.tableView.accessibilityIdentifier=@"UsersDevicesVCDTableView";
    self.tableView.dataSource = self;

    // Register collection view cell class
    [self.tableView registerClass:DeviceTableViewCell.class forCellReuseIdentifier:[DeviceTableViewCell defaultReuseIdentifier]];

    // Hide line separators of empty cells
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    // Check the table view style to select its bg color.
    self.tableView.backgroundColor = ((self.tableView.style == UITableViewStylePlain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor);
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    
    if (self.tableView.dataSource)
    {
        [self.tableView reloadData];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)destroy
{
    [super destroy];
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"UnknowDevices"];

    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return usersDevices.userIds.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return usersDevices.userIds[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *userId = usersDevices.userIds[section];
    return [usersDevices deviceIdsForUser:userId].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;

    MXDeviceInfo *device = [self deviceAtIndexPath:indexPath];
    if (device)
    {
        DeviceTableViewCell *deviceCell = [tableView dequeueReusableCellWithIdentifier:[DeviceTableViewCell defaultReuseIdentifier] forIndexPath:indexPath];
        deviceCell.selectionStyle = UITableViewCellSelectionStyleNone;

        [deviceCell render:device];
        deviceCell.delegate = self;

        cell = deviceCell;
    }
    else
    {
        // Return a fake cell to prevent app from crashing.
        cell = [[UITableViewCell alloc] init];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    // Update the selected background view
    if (ThemeService.shared.theme.selectedBackgroundColor)
    {
        cell.selectedBackgroundView = [[UIView alloc] init];
        cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
    }
    else
    {
        if (tableView.style == UITableViewStylePlain)
        {
            cell.selectedBackgroundView = nil;
        }
        else
        {
            cell.selectedBackgroundView.backgroundColor = nil;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MXDeviceInfo *device = [self deviceAtIndexPath:indexPath];

    return [DeviceTableViewCell cellHeightWithDeviceInfo:device andCellWidth:self.tableView.frame.size.width];
}

#pragma mark - DeviceTableViewCellDelegate

- (void)deviceTableViewCell:(DeviceTableViewCell *)deviceTableViewCell updateDeviceVerification:(MXDeviceVerification)verificationStatus
{
    if (verificationStatus == MXDeviceVerified)
    {
        // Prompt the user before marking as verified the device.
        deviceVerificationCoordinatorBridgePresenter = [[DeviceVerificationCoordinatorBridgePresenter alloc] initWithSession:mxSession];
        deviceVerificationCoordinatorBridgePresenter.delegate = self;

        [deviceVerificationCoordinatorBridgePresenter presentFrom:self otherUserId:deviceTableViewCell.deviceInfo.userId otherDeviceId:deviceTableViewCell.deviceInfo.deviceId animated:YES];
    }
    else
    {
        [mxSession.crypto setDeviceVerification:verificationStatus
                                      forDevice:deviceTableViewCell.deviceInfo.deviceId
                                         ofUser:deviceTableViewCell.deviceInfo.userId
                                        success:^{

                                            deviceTableViewCell.deviceInfo.verified = verificationStatus;
                                            [self.tableView reloadData];

                                        } failure:nil];
    }
}

#pragma mark - DeviceVerificationCoordinatorBridgePresenterDelegate

- (void)deviceVerificationCoordinatorBridgePresenterDelegateDidComplete:(DeviceVerificationCoordinatorBridgePresenter *)coordinatorBridgePresenter otherUserId:(NSString * _Nonnull)otherUserId otherDeviceId:(NSString * _Nonnull)otherDeviceId
{
    [deviceVerificationCoordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    deviceVerificationCoordinatorBridgePresenter = nil;

    // Update our map
    MXWeakify(self);
    [mxSession.crypto downloadKeys:@[otherUserId] forceDownload:NO success:^(MXUsersDevicesMap<MXDeviceInfo *> *usersDevicesInfoMap) {
        MXStrongifyAndReturnIfNil(self);

        MXDeviceInfo *deviceInfo = [usersDevicesInfoMap objectForDevice:otherDeviceId forUser:otherUserId];

        MXDeviceInfo *device = [self->usersDevices objectForDevice:otherDeviceId forUser:otherUserId];
        device.verified = deviceInfo.verified;

        [self.tableView reloadData];

    } failure:^(NSError *error) {
        // Should not happen (the device is in the crypto db)
    }];
}


#pragma mark - User actions

- (IBAction)onDone:(id)sender
{
    // Acknowledge the existence of all devices before leaving this screen
    [self startActivityIndicator];
    [mxSession.crypto setDevicesKnown:usersDevices complete:^{

        [self stopActivityIndicator];
        [self dismissViewControllerAnimated:YES completion:nil];

        if (onCompleteBlock)
        {
            onCompleteBlock(YES);
        }
    }];
}

- (IBAction)onCancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];

    if (onCompleteBlock)
    {
        onCompleteBlock(NO);
    }
}

#pragma mark - Private methods

- (MXDeviceInfo*)deviceAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *userId = usersDevices.userIds[indexPath.section];
    NSString *deviceId = [usersDevices deviceIdsForUser:userId][indexPath.row];

    return [usersDevices objectForDevice:deviceId forUser:userId];
}

@end
