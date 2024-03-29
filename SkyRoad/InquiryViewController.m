//
//  InquiryViewController.m
//  SkyRoad
//
//  Created by alan on 17/3/22.
//  Copyright © 2017年 sibet. All rights reserved.
//
//// test

#import "InquiryViewController.h"
#import "UIView+Toast.h"
#import "FSCalendar.h"
//#import "SQLManager.h"
#import "DeviceSQLManager.h"
#import "AFNetworking.h"

/** 坐标转换需要用到的头文件 **/
#import <AMapFoundationKit/AMapFoundationKit.h>

// 宏定义-导航栏的高度 - shi 44
//#define JNavBarH self.navigationController.navigationBar.frame.size.height+20+20
#define JNavBarH 64

#define JScreenWidth [[UIScreen mainScreen]bounds].size.width
#define JScreenHeight [[UIScreen mainScreen]bounds].size.height
#define JrouteColor [UIColor colorWithRed:251/255.0 green:71/255.0 blue:71/255.0 alpha:0.9]

@interface InquiryViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, MAMapViewDelegate, FSCalendarDataSource,FSCalendarDelegate,FSCalendarDelegateAppearance>

{
    UITableView *_pigeonTableView1;
}
// 公历
@property (strong, nonatomic) NSCalendar *gregorian;
// checkMark 操作
@property (nonatomic,strong) NSIndexPath *lastPath2;
/** 存储起点，终点 **/
@property (nonatomic, strong) NSMutableArray *startAndEndAnnotation;
@property (nonatomic, strong) MAPointAnnotation *startAnnotaion;
@property (nonatomic, strong) MAPointAnnotation *endAnnotaion;
@property (strong, nonatomic) NSDate *minimumDate;
@property (strong, nonatomic) NSDate *maximumDate;
@property (strong, nonatomic) NSCache *cache;
@property (assign, nonatomic) BOOL showsCalendar;

@property (nonatomic, copy) NSMutableArray *pigeonArr;
@property (nonatomic, strong) UIPickerView *pigeonPicker;

@property (weak, nonatomic) IBOutlet UILabel *calendarLabel;
/** 存储所选信鸽所有存在轨迹的日期 **/
@property (strong, nonatomic) NSArray *datesWithPath;

@end

@implementation InquiryViewController

dispatch_queue_t global_queue1;
NSString *pigeonChosen;
NSString *startTime;
NSString *endTime;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.tabBarItem.title = @"查询";
        UIImage *i = [UIImage imageNamed:@"Inquiry_BarItem.png"];
        self.tabBarItem.image = i;
        
        // 自定义itemView
        UIButton *calendarButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 22, 22)];
        [calendarButton addTarget:self action:@selector(showCalendar:) forControlEvents:UIControlEventTouchUpInside];
        [calendarButton setImage:[UIImage imageNamed:@"Inquiry_TitleItem.png"] forState:UIControlStateNormal];
        self.navigationItem.titleView = calendarButton;
        
        // 自定义leftItem
        UIButton *listButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 22, 22)];
        [listButton addTarget:self action:@selector(listItemClicked:) forControlEvents:UIControlEventTouchUpInside];
        [listButton setImage:[UIImage imageNamed:@"Inquiry_List.png"] forState:UIControlStateNormal];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:listButton];
        // 自定义rightItem
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"开始查询" style:UIBarButtonItemStylePlain target:self action:@selector(startInquiry)];
        
        self.gregorian = [[NSCalendar alloc]initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
     
        [self setupMapProperty];
        [self calendarInitial];
        [self initPigeonArr];
        [self initPigeonPickerView];
//        [self initPigeonTableview];
    }
    return self;
}

- (void)initPigeonArr {
    // 取出数据库存放的信鸽数据
    
    _pigeonArr = [[NSMutableArray alloc]init];
    
    NSMutableArray *arr = [[NSMutableArray alloc]init];
    DeviceSQLManager *manager = [DeviceSQLManager shareManager];
    NSMutableArray *pigeonModelArr = [manager searchAll];
    NSInteger pigeonCount = [pigeonModelArr count];
    for (int i = 0; i < (int)pigeonCount; i++) {
        DeviceDetailModel *model = pigeonModelArr[i];
        NSString *nameStr = model.deviceNum;
        [arr addObject:nameStr];
    }
    _pigeonArr = arr;
    
//    NSMutableArray *arr = [[NSMutableArray alloc]init];
//    SQLManager *manager = [SQLManager shareManager];
//    NSMutableArray *pigeonModelArr = [manager searchAll];
//    NSInteger pigeonCount = [pigeonModelArr count];
//    for (int i = 0; i < (int)pigeonCount; i++) {
//        PigeonDetailModel *model = pigeonModelArr[i];
//        NSString *nameStr = model.pigeonRingNumber;
//        [arr addObject:nameStr];
//    }
//    _pigeonArr = arr;
}

- (void)calendarInitial
{
    FSCalendar *calendar = [[FSCalendar alloc] initWithFrame:CGRectMake(0, JNavBarH, JScreenWidth, 300)];
    calendar.appearance.weekdayTextColor = [UIColor colorWithRed:28/255.0 green:144/255.0 blue:156/255.0 alpha:1.0];
    calendar.appearance.headerTitleColor = [UIColor colorWithRed:28/255.0 green:144/255.0 blue:156/255.0 alpha:1.0];
    calendar.appearance.borderRadius = 0;
    calendar.backgroundColor = [UIColor whiteColor];
    // 设置显示月份的格式
    calendar.appearance.headerDateFormat = @"yyyy年MM月";
    calendar.dataSource = self;
    calendar.delegate = self;
    calendar.hidden = NO;
    [self.view addSubview:calendar];
    self.calendar = calendar;
}

- (void)initPigeonTableview
{
    CGRect rect = CGRectMake(0, JNavBarH, 150, 200);
    _pigeonTableView1 = [[UITableView alloc]initWithFrame:rect style:UITableViewStylePlain];
    
    _pigeonTableView1.layer.borderWidth = 1.0;
    _pigeonTableView1.layer.borderColor = [UIColor grayColor].CGColor;
    _pigeonTableView1.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    _pigeonTableView1.delegate = self;
    _pigeonTableView1.dataSource = self;
    _pigeonTableView1.hidden = YES;
    [self.view addSubview:_pigeonTableView1];
}

- (void)initPigeonPickerView
{
    CGRect rect = CGRectMake(0, 64, 120, 136);
    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:rect];
    picker.layer.borderWidth = 0.7;
    picker.layer.borderColor = [UIColor lightGrayColor].CGColor;
    picker.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
//    picker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    picker.delegate = self;
    picker.dataSource = self;
    picker.showsSelectionIndicator = YES;
    [self.view addSubview:picker];
    self.pigeonPicker = picker;
    [self.pigeonPicker setHidden:YES];
}

- (void)setupMapProperty
{
    // 初始化地图
    _mapView = [[MAMapView alloc]initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //    // 设置指南针位置
    //    _mapView.compassOrigin = CGPointMake(_mapView.compassOrigin.x, 65);
    //    // 设置比例尺控件
//    _mapView.scaleOrigin = CGPointMake(_mapView.scaleOrigin.x, 70);
    // 设置地图缩放级别 [3-19]
    //    [_mapView setZoomLevel:14.0 animated:YES];
    // 缩放手势开启
    _mapView.zoomEnabled = YES;
    // 拖动手势开启
    _mapView.scrollEnabled = YES;
    // 进入地图就显示定位小蓝点
//    _mapView.showsUserLocation = YES;
    // 地图跟着位置移动
    //    [_mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
    _mapView.delegate = self;
    [self.view addSubview:_mapView];
    
}

- (void)listItemClicked:(id)sender
{
//    self.calendar.hidden = YES;
//    _pigeonTableView1.hidden = ! _pigeonTableView1.hidden;
    [self.view endEditing:YES];
    [self.calendar setHidden:YES];
    self.pigeonPicker.hidden = !self.pigeonPicker.hidden;
}

- (void)showCalendar:(id)sender
{
    _pigeonTableView1.hidden = YES;
    _pigeonPicker.hidden = YES;
    _calendar.hidden = !_calendar.hidden;
    if (_calendar.hidden == NO && pigeonChosen.length) {
        [self getPathDatesFromWeb:pigeonChosen];
    }
}

- (void)getPathDatesFromWeb:(NSString*)targetStr
{
    // 定义web服务器接口
    NSString *domainStr = [NSString stringWithFormat:@"http://b.airlord.cn:31568/trace/queryOn?sbid=%@", targetStr];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager GET:domainStr parameters:nil progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        id searializeObj = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
//        NSLog(@"searializeObj:%@",searializeObj);
        if ([searializeObj isKindOfClass:[NSDictionary class]]) {
            NSLog(@"查询轨迹历史天数信息:%@",searializeObj);
            _datesWithPath = nil;
            [self.calendar reloadData];
            return;
        }
        else if ([searializeObj isKindOfClass:[NSArray class]]){
            NSMutableArray *dateArr = [[NSMutableArray alloc]init];
            long objC = [(NSArray*)searializeObj count];
            for (int i=0; i < objC; i++) {
                NSDictionary *pathDatesDic = [(NSArray*)searializeObj objectAtIndex:i];
                id date = [pathDatesDic objectForKey:@"data"];
                NSString *dateStr = [NSString stringWithFormat:@"%@",date];
                [dateArr addObject:dateStr];
            }
            _datesWithPath = [NSArray arrayWithArray:dateArr];
            [self.calendar reloadData];
        }
        else {
            return;
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"查询历史天数失败");
        NSLog(@"task:%@",task);
        NSLog(@"error:%@",error);
    }];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    global_queue1 = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self initPigeonArr];
    _pigeonPicker.delegate = self;
    _pigeonPicker.delegate = self;
    _calendar.dataSource = self;
    _calendar.delegate = self;
//    [_pigeonTableView1 reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
//    _pigeonTableView1.delegate = nil;
//    _pigeonTableView1.dataSource = nil;
    _pigeonPicker.hidden = YES;
    _calendar.hidden = YES;
    _pigeonPicker.delegate = nil;
    _pigeonPicker.delegate = nil;
    _calendar.dataSource = nil;
    _calendar.delegate = nil;
}

- (void)dealloc
{
    NSLog(@"%s", __FUNCTION__);
}

# pragma mark - unix时间戳转换为时间字符串
// 输入unix时间戳对象，返回日期字符串对象
- (NSString *)unixTimeStampTransferToDateString:(NSTimeInterval)timeInterval
{
    // 设置日期显示格式
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
//    dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss";
    dateFormatter.dateFormat = @"yyyyMMdd";
    // 时间戳timeInterval转换成日期对象
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    // 日期对象返回日期字符串
    NSString *dateStr = [dateFormatter stringFromDate:date];
//    NSLog(@"dateStr:%@",dateStr);
    return dateStr;
}

#pragma mark - 网络请求

- (void)startInquiry
{
    self.calendar.hidden = YES;
    _pigeonPicker.hidden = YES;
    if (!pigeonChosen.length) {
        CGPoint point = CGPointMake(JScreenWidth/2, JNavBarH+20);
        NSValue *value = [NSValue valueWithCGPoint:point];
        [self.view makeToast:@"请选择待查信鸽" duration:2.0 position:value];
    } else if (!startTime.length) {
        CGPoint point = CGPointMake(JScreenWidth/2, JNavBarH+20);
        NSValue *value = [NSValue valueWithCGPoint:point];
        [self.view makeToast:@"请选择查询日期" duration:2.0 position:value];
    } else {
        dispatch_async(global_queue1, ^{
            [self dataFromWeb];
        });
    }
}

- (void)dataFromWeb
{

    NSString *urlStr = [NSString stringWithFormat:@"http://b.airlord.cn:31568/trace/query?sbid=%@&data=%@",pigeonChosen,startTime];
//    NSString *urlStr = [NSString stringWithFormat:@"http://b.airlord.cn:31568/trace/query?sbid=2017001&data=20170401"];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    //    //使用POST方法
    //    req.HTTPMethod = @"POST";
    //    //POST参数
    //    NSString *param = @"2017002";
    //    //POST请求参数的拼接
    //    NSString *postParam = [NSString stringWithFormat:@"id=%@",param];
    //    //进行格式转换
    //    NSData *postData = [postParam dataUsingEncoding:NSUTF8StringEncoding];
    //    //POST请求参数使用如下方法进行赋值
    //    req.HTTPBody = postData;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    // delegate设置为nil，因为session对象并不需要实现委托方法
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        NSLog(@"response:%@",response);
        if (data==nil) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"网络请求失败" message:@"请检查您的网络状况" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"我知道了" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [self presentViewController:alert animated:YES completion:nil];
            
        } else {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([obj isKindOfClass:[NSArray class]]) {
                [self initStartAndEndAnnotation];
                long objCount = [(NSArray*)obj count];
                // 网络连接状态良好，查询参数无误（信鸽名字／日期），只是轨迹无数据
                if(objCount == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.mapView removeOverlays:self.mapView.overlays];
                        [self.mapView removeAnnotations:self.mapView.annotations];
                        self.mapView.showsUserLocation = YES;
                        self.mapView.userTrackingMode = MAUserTrackingModeFollow;
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无轨迹信息" message:nil preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"我知道了" style:UIAlertActionStyleDefault handler:nil];
                        [alert addAction:okAction];
                        [self presentViewController:alert animated:YES completion:nil];
                    });
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.mapView removeOverlays:self.mapView.overlays];
                        [self.mapView removeAnnotations:self.mapView.annotations];
                        self.mapView.showsUserLocation = NO;
                    });
                    // 服务器上的坐标为GPS坐标
                    CLLocationCoordinate2D commoPolylineCoordGPS[objCount];
                    //GPS坐标转换成高德坐标系
                    CLLocationCoordinate2D commoPolylineCoord[objCount];
                    CLLocationDegrees minLat = 90.0;
                    CLLocationDegrees maxLat = -90.0;
                    CLLocationDegrees minLon = 180.0;
                    CLLocationDegrees maxLon = -180.0;
                    
                    for (int i = 0; i < objCount; i++) {
                        NSDictionary *locationDic = [(NSArray *)obj objectAtIndex:i];
                        NSString *lat = [(NSDictionary *)locationDic objectForKey:@"latitude"];
                        double lati = [lat doubleValue];
                        NSString *lon = [(NSDictionary *)locationDic objectForKey:@"longitude"];
                        double longi = [lon doubleValue];
                        
                        commoPolylineCoordGPS[i].latitude = lati;
                        commoPolylineCoordGPS[i].longitude = longi;
                        
                        AMapCoordinateType type = AMapCoordinateTypeGPS;
                        commoPolylineCoord[i] = AMapCoordinateConvert(commoPolylineCoordGPS[i],type);
                        
                        minLat = MIN(minLat, commoPolylineCoord[i].latitude);
                        maxLat = MAX(maxLat, commoPolylineCoord[i].latitude);
                        minLon = MIN(minLon, commoPolylineCoord[i].longitude);
                        maxLon = MAX(maxLon, commoPolylineCoord[i].longitude);
                        
                        // 起点坐标
                        self.startAnnotaion.coordinate = CLLocationCoordinate2DMake(commoPolylineCoord[0].latitude, commoPolylineCoord[0].longitude);
                        self.startAnnotaion.title = @"起点";
                        
                        // 终点坐标
                        self.endAnnotaion.coordinate = CLLocationCoordinate2DMake(commoPolylineCoord[objCount-1].latitude, commoPolylineCoord[objCount-1].longitude);
                        self.endAnnotaion.title = @"终点";
                        [self.startAndEndAnnotation addObject:self.startAnnotaion];
                        [self.startAndEndAnnotation addObject:self.endAnnotaion];
                    }
                    CLLocationCoordinate2D centerCoord = CLLocationCoordinate2DMake((minLat + maxLat) * 0.5f, (minLon + maxLon) * 0.5f);
                    MACoordinateSpan viewSapn;
                    viewSapn.latitudeDelta = (maxLat - minLat) * 3;
                    viewSapn.longitudeDelta = (maxLon - minLon) * 3;
                    MACoordinateRegion viewRegion;
                    viewRegion.center = centerCoord;
                    viewRegion.span = viewSapn;
                    
                    MAPolyline *Polyline = [MAPolyline polylineWithCoordinates:commoPolylineCoord count:[(NSArray*)obj count]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_mapView setRegion:viewRegion];
                        // 构造折线对象
                        [_mapView addOverlay:Polyline];
                        [_mapView addAnnotations:self.startAndEndAnnotation];
                    });
                }
            }
        }
    }];
    [dataTask resume];
}

- (void)initStartAndEndAnnotation
{
    _startAnnotaion = [[MAPointAnnotation alloc]init];
    _endAnnotaion = [[MAPointAnnotation alloc]init];
    
    _startAndEndAnnotation = [NSMutableArray array];
}

#pragma mark - tableView
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.pigeonArr.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
        static NSString *cellIdentifier = @"cellIdentifier";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            
            cell.textLabel.text = _pigeonArr[indexPath.row];
            
            NSInteger row = [indexPath row];
            NSInteger oldRow = [_lastPath2 row];
            if (row == oldRow && self.lastPath2!=nil) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
        return cell;

    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

    pigeonChosen = [self.pigeonArr objectAtIndex:indexPath.row];
    
    CGPoint point = CGPointMake(JScreenWidth/2, JNavBarH+20);
    NSValue *value = [NSValue valueWithCGPoint:point];
    [self.view makeToast:[NSString stringWithFormat:@"信鸽名字：%@",pigeonChosen] duration:1.0 position:value];
    
    int newRow = (int)[indexPath row];
    int oldRow = (_lastPath2!=nil)?(int)[_lastPath2 row]:-1;
    if (newRow != oldRow) {
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;
        UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:_lastPath2];
        oldCell.accessoryType = UITableViewCellAccessoryNone;
        _lastPath2 = indexPath;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

#pragma mark - UIPickerViewDelegate
- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [self.pigeonArr objectAtIndex:row];
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 40;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    pigeonChosen = [self.pigeonArr objectAtIndex:row];
    CGPoint point = CGPointMake(JScreenWidth/2, JNavBarH+20);
    NSValue *value = [NSValue valueWithCGPoint:point];
    [self.view makeToast:[NSString stringWithFormat:@"设备号：%@",pigeonChosen] duration:1.0 position:value];
}
#pragma mark - UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.pigeonArr.count;
}

#pragma mark - FSCalendar

- (void)calendar:(FSCalendar *)calendar didSelectDate:(NSDate *)date atMonthPosition:(FSCalendarMonthPosition)monthPosition
{
    // 设置日期显示格式
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = @"yyyyMMdd";
    // 时间戳timeInterval转换成日期对象
    NSDate *d = date;
    // 日期对象返回日期字符串
    NSString *dateStr = [dateFormatter stringFromDate:d];
    startTime = dateStr;
    /*
     @param message The message to be displayed
     @param duration The toast duration
     @param position The toast's center point. Can be one of the predefined CSToastPosition
     constants or a `CGPoint` wrapped in an `NSValue` object.
     */
    CGPoint point = CGPointMake(JScreenWidth/2, JNavBarH+20);
    NSValue *value = [NSValue valueWithCGPoint:point];
    [self.view makeToast:[NSString stringWithFormat:@"日期：%@",startTime] duration:1.0 position:value];
}

#pragma mark - <FSCalendarDataSource>

- (NSInteger)calendar:(FSCalendar *)calendar numberOfEventsForDate:(NSDate *)date
{
    // 设置日期显示格式
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = @"yyyyMMdd";
    NSString *dateString = [dateFormatter stringFromDate:date];

    if ([self.datesWithPath containsObject:dateString]) {
        return 1;
    }
    else {
        return 0;
    }
}

#pragma mark - <FSCalendarDelegateAppearance>

- (NSArray *)calendar:(FSCalendar *)calendar appearance:(FSCalendarAppearance *)appearance eventDefaultColorsForDate:(NSDate *)date
{

//    return @[[UIColor magentaColor],appearance.eventDefaultColor,[UIColor greenColor]];
    return @[[UIColor redColor]];
}


#pragma mark - Private methods

//// 事件、节日
//- (void)loadCalendarEvents
//{
//    __weak typeof(self) weakSelf = self;
//    EKEventStore *store = [[EKEventStore alloc] init];
//    [store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
//        
//        if(granted) {
//            NSDate *startDate = self.minimumDate;
//            NSDate *endDate = self.maximumDate;
//            NSPredicate *fetchCalendarEvents = [store predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
//            NSArray<EKEvent *> *eventList = [store eventsMatchingPredicate:fetchCalendarEvents];
//            NSArray<EKEvent *> *events = [eventList filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(EKEvent * _Nullable event, NSDictionary<NSString *,id> * _Nullable bindings) {
//                return event.calendar.subscribed;
//            }]];
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                if (!weakSelf) return;
//                weakSelf.events = events;
//                [weakSelf.calendar reloadData];
//            });
//            
//        } else {
//            
//            // Alert
//            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Permission Error" message:@"Permission of calendar is required for fetching events." preferredStyle:UIAlertControllerStyleAlert];
//            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
//            [self presentViewController:alertController animated:YES completion:nil];
//        }
//    }];
//    
//}
//
//- (NSArray<EKEvent *> *)eventsForDate:(NSDate *)date
//{
//    NSArray<EKEvent *> *events = [self.cache objectForKey:date];
//    if ([events isKindOfClass:[NSNull class]]) {
//        return nil;
//    }
//    NSArray<EKEvent *> *filteredEvents = [self.events filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(EKEvent * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
//        return [evaluatedObject.occurrenceDate isEqualToDate:date];
//    }]];
//    if (filteredEvents.count) {
//        [self.cache setObject:filteredEvents forKey:date];
//    } else {
//        [self.cache setObject:[NSNull null] forKey:date];
//    }
//    return filteredEvents;
//}
// FSCalendar doesn't update frame by itself, please implement
// For AutoLayout
//- (void)calendar:(FSCalendar*)calendar boundingRectWillChange:(CGRect)bounds animated:(BOOL)animated
//{
//    self.calendar.calendarHeightConstraint.constant = CGRectGetHeight(bounds);
//    [self.view layoutIfNeeded];
//    
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)showCalendarDate:(id)sender {
    // 设置日期显示格式
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    // 时间戳timeInterval转换成日期对象
    NSDate *date = self.calendar.selectedDate;
    // 日期对象返回日期字符串
    NSString *dateStr = [dateFormatter stringFromDate:date];
//    NSLog(@"dateStr:%@",dateStr);
    self.calendarLabel.text = dateStr;
}


# pragma mark - <MAMapViewDelegate>
/* 设置地图annotation的样式*/
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString *pointReuseIdentifier = @"pointReuseIdentifier";
        MAAnnotationView *annotationView = (MAAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIdentifier];
        if (annotationView == nil) {
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIdentifier];
        }
        annotationView.canShowCallout = YES;
        if ([annotation.title isEqualToString:(NSString*)@"起点"]) {
            annotationView.image = [UIImage imageNamed:@"Track_routeStart"];
        }
        else if ([annotation.title isEqualToString:(NSString*)@"终点"]) {
            annotationView.image = [UIImage imageNamed:@"Track_routeEnd"];
        }
//        annotationView.animatesDrop = YES;
//        annotationView.pinColor = [self.startAndEndAnnotation indexOfObject:annotation];  // 0：红色  1：绿色  2：紫色
        annotationView.centerOffset = CGPointMake(0, -(annotationView.frame.size.height * 0.5));
        return annotationView;
    }
    return nil;
    
}

// 实现代理方法，得把自己设置成代理啊！self.mapView.delegate = self
// 回调函数，设置折线的样式
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]])
    {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc]initWithPolyline:overlay];
        
        polylineRenderer.lineWidth = 3.5f;
        polylineRenderer.strokeColor = JrouteColor;
        polylineRenderer.lineJoin = kCGLineJoinRound;
        polylineRenderer.lineCap = kCGLineCapRound;
        
        return polylineRenderer;
    }
    return  nil;
}
@end
