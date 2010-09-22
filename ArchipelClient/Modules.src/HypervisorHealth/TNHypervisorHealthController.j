/*
 * TNViewHypervisorControl.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import <LPKit/LPKit.j>
//@import "LPChartView.j"

@import "TNDatasourceGraphCPU.j"
@import "TNDatasourceGraphMemory.j"
@import "TNDatasourceGraphDisks.j"
@import "TNDatasourceGraphLoad.j"
@import "TNLogEntryObject.j"

TNArchipelTypeHypervisorHealth              = @"archipel:hypervisor:health";
TNArchipelTypeHypervisorHealthInfo          = @"info";
TNArchipelTypeHypervisorHealthHistory       = @"history";
TNArchipelTypeHypervisorHealthLog           = @"logs";

TNArchipelHealthRefreshBaseKey              = @"TNArchipelHealthRefreshBaseKey_";

LPAristo = nil;

@implementation TNHypervisorHealthController : TNModule
{
    @outlet CPImageView         imageCPULoading;
    @outlet CPImageView         imageMemoryLoading;
    @outlet CPImageView         imageLoadLoading;
    @outlet CPImageView         imageDiskLoading;
    @outlet CPTextField         fieldHalfMemory;
    @outlet CPTextField         fieldJID;
    @outlet CPTextField         fieldName;
    @outlet CPTextField         fieldTotalMemory;
    @outlet CPTextField         healthCPUUsage;
    @outlet CPTextField         healthDiskUsage;
    @outlet CPTextField         healthInfo;
    @outlet CPTextField         healthLoad;
    @outlet CPTextField         healthMemSwapped;
    @outlet CPTextField         healthMemUsage;
    @outlet CPTextField         healthUptime;
    @outlet CPView              viewGraphCPU;
    @outlet CPView              viewGraphMemory;
    @outlet CPView              viewGraphLoad;
    @outlet CPView              viewGraphDisk;
    @outlet TNSwitch            switchRefresh;
    
    @outlet CPView              viewGraphCPUContainer;
    @outlet CPView              viewGraphMemoryContainer;
    @outlet CPView              viewGraphLoadContainer;
    @outlet CPView              viewGrapDiskContainer;
    
    @outlet CPTabView           tabViewInfos;
    @outlet CPView              viewCharts;
    @outlet CPView              viewLogs;
    @outlet CPView              viewLogsTableContainer;
    @outlet CPScrollView        scrollViewLogsTable;
    @outlet CPSearchField       filterLogField;
    
    CPNumber                    _statsHistoryCollectionSize;
    CPTimer                     _timerStats;
    CPTimer                     _timerLogs;
    float                       _timerInterval;
    int                         _maxLogEntries;
    BOOL                        _tableLogDisplayMethodColumn;
    BOOL                        _tableLogDisplayFileColumn;
    LPChartView                 _chartViewCPU;
    LPChartView                 _chartViewMemory;
    LPChartView                 _chartViewLoad;
    LPPieChartView              _chartViewDisk;
    TNDatasourceGraphCPU        _cpuDatasource;
    TNDatasourceGraphMemory     _memoryDatasource;
    TNDatasourceGraphLoad       _loadDatasource;
    TNDatasourceGraphDisks      _disksDatasource;
    
    CPTableView                 _tableLogs;
    TNTableViewDataSource       _datasourceLogs;
    
}

- (void)awakeFromCib
{
    [fieldJID setSelectable:YES];
    
    var bundle  = [CPBundle bundleForClass:[self class]];
    var spinner = [[CPImage alloc] initWithContentsOfFile:[bundle pathForResource:@"loading.gif"]];

    [imageCPULoading setImage:spinner];
    [imageMemoryLoading setImage:spinner];
    [imageLoadLoading setImage:spinner];
    [imageDiskLoading setImage:spinner];
    
    [imageCPULoading setHidden:YES];
    [imageMemoryLoading setHidden:YES];
    [imageLoadLoading setHidden:YES];
    [imageDiskLoading setHidden:YES];

    [viewGraphCPUContainer setBackgroundColor:[CPColor colorWithHexString:@"F5F6F7"]];
    [viewGraphMemoryContainer setBackgroundColor:[CPColor colorWithHexString:@"F5F6F7"]];
    [viewGraphLoadContainer setBackgroundColor:[CPColor colorWithHexString:@"F5F6F7"]];
    [viewGrapDiskContainer setBackgroundColor:[CPColor colorWithHexString:@"F5F6F7"]];
    
    [viewGraphCPUContainer setBorderRadius:4];
    [viewGraphMemoryContainer setBorderRadius:4];
    [viewGraphLoadContainer setBorderRadius:4];
    [viewGrapDiskContainer setBorderRadius:4];
    
    var cpuViewFrame = [viewGraphCPU bounds];

    _chartViewCPU   = [[LPChartView alloc] initWithFrame:cpuViewFrame];
    [_chartViewCPU setDrawViewPadding:1.0];
    [_chartViewCPU setLabelViewHeight:0.0];
    [_chartViewCPU setDrawView:[[TNChartDrawView alloc] init]];
    [_chartViewCPU setFixedMaxValue:100];
    [_chartViewCPU setDisplayLabels:NO];
    [[_chartViewCPU gridView] setBackgroundColor:[CPColor whiteColor]];
    [viewGraphCPU addSubview:_chartViewCPU];

    var memoryViewFrame = [viewGraphMemory bounds];

    _chartViewMemory   = [[LPChartView alloc] initWithFrame:memoryViewFrame];
    [_chartViewMemory setDrawViewPadding:1.0];
    [_chartViewMemory setLabelViewHeight:0.0];
    [_chartViewMemory setDrawView:[[TNChartDrawView alloc] init]];
    [_chartViewMemory setDisplayLabels:NO];
    [[_chartViewMemory gridView] setBackgroundColor:[CPColor whiteColor]];
    [viewGraphMemory addSubview:_chartViewMemory];
    
    var loadViewFrame = [viewGraphLoad bounds];

    _chartViewLoad   = [[LPChartView alloc] initWithFrame:loadViewFrame];
    [_chartViewLoad setDrawViewPadding:1.0];
    [_chartViewLoad setLabelViewHeight:0.0];
    [_chartViewLoad setDrawView:[[TNChartDrawView alloc] init]];
    [_chartViewLoad setFixedMaxValue:1000];
    [_chartViewLoad setDisplayLabels:YES];
    [[_chartViewLoad gridView] setBackgroundColor:[CPColor whiteColor]];
    [viewGraphLoad addSubview:_chartViewLoad];
    
    var diskViewFrame = [viewGraphDisk bounds];

    _chartViewDisk   = [[LPPieChartView alloc] initWithFrame:diskViewFrame];
    [_chartViewDisk setDrawView:[[TNPieChartDrawView alloc] init]];
    [viewGraphDisk addSubview:_chartViewDisk];
    [_chartViewDisk setDelegate:self];

    var moduleBundle = [CPBundle bundleForClass:[self class]]
    _timerInterval              = [moduleBundle objectForInfoDictionaryKey:@"TNArchipelHealthRefreshStatsInterval"];
    _statsHistoryCollectionSize = [moduleBundle objectForInfoDictionaryKey:@"TNArchipelHealthStatsHistoryCollectionSize"];
    _maxLogEntries              = [moduleBundle objectForInfoDictionaryKey:@"TNArchipelHealthMaxLogEntry"];
    
    _tableLogDisplayFileColumn    = [moduleBundle objectForInfoDictionaryKey:@"TNArchipelHealthTableLogDisplayFileColumn"];
    _tableLogDisplayMethodColumn    = [moduleBundle objectForInfoDictionaryKey:@"TNArchipelHealthTableLogDisplayMethodColumn"];
    
    
    // tabview
    [tabViewInfos setBorderColor:[CPColor colorWithHexString:@"789EB3"]]

    var tabViewItemCharts = [[CPTabViewItem alloc] initWithIdentifier:@"id1"];
    [tabViewItemCharts setLabel:@"Charts"];
    [tabViewItemCharts setView:viewCharts];
    [tabViewInfos addTabViewItem:tabViewItemCharts];
    
    var tabViewItemLogs = [[CPTabViewItem alloc] initWithIdentifier:@"id2"];
    [tabViewItemLogs setLabel:@"Logs"];
    [tabViewItemLogs setView:viewLogs];
    [tabViewInfos addTabViewItem:tabViewItemLogs];
    
    // logs tables
    _datasourceLogs = [[TNTableViewDataSource alloc] init];
    _tableLogs      = [[CPTableView alloc] initWithFrame:[scrollViewLogsTable bounds]];
    
    [viewLogsTableContainer setBorderedWithHexColor:@"#C0C7D2"];
    [scrollViewLogsTable setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [scrollViewLogsTable setAutohidesScrollers:YES];
    [scrollViewLogsTable setDocumentView:_tableLogs];
    
    [_tableLogs setUsesAlternatingRowBackgroundColors:YES];
    [_tableLogs setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [_tableLogs setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [_tableLogs setAllowsColumnReordering:NO];
    [_tableLogs setAllowsColumnResizing:YES];
    [_tableLogs setAllowsEmptySelection:YES];
    [_tableLogs setAllowsMultipleSelection:NO];
    
    var columnLogLevel = [[CPTableColumn alloc] initWithIdentifier:@"level"];
    [columnLogLevel setWidth:50];
    [columnLogLevel setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"level" ascending:YES]];
    [[columnLogLevel headerView] setStringValue:@"Level"];
    
    var columnLogDate = [[CPTableColumn alloc] initWithIdentifier:@"date"];
    [columnLogDate setWidth:125];
    [columnLogDate setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    [[columnLogDate headerView] setStringValue:@"Date"];
    
    var columnLogFile = [[CPTableColumn alloc] initWithIdentifier:@"file"];
    [columnLogFile setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"file" ascending:YES]];
    [[columnLogFile headerView] setStringValue:@"file"];
    
    var columnLogMethod = [[CPTableColumn alloc] initWithIdentifier:@"method"];
    [columnLogMethod setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"method" ascending:YES]];
    [[columnLogMethod headerView] setStringValue:@"method"];
    
    var columnLogMessage = [[CPTableColumn alloc] initWithIdentifier:@"message"];
    [columnLogMessage setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"message" ascending:YES]];
    [[columnLogMessage headerView] setStringValue:@"message"];
    
    [_tableLogs addTableColumn:columnLogLevel];
    [_tableLogs addTableColumn:columnLogDate];
    if (_tableLogDisplayFileColumn)
        [_tableLogs addTableColumn:columnLogFile];
    if (_tableLogDisplayMethodColumn)
        [_tableLogs addTableColumn:columnLogMethod];
    [_tableLogs addTableColumn:columnLogMessage];

    [_datasourceLogs setTable:_tableLogs];
    [_datasourceLogs setSearchableKeyPaths:[@"level", @"date", @"message"]];
    
    [filterLogField setTarget:_datasourceLogs];
    [filterLogField setAction:@selector(filterObjects:)];
    
    // refresh switch
    [switchRefresh setTarget:self];
    [switchRefresh setAction:@selector(pauseRefresh:)];
}



- (IBAction)pauseRefresh:(id)sender
{
    var defaults    = [TNUserDefaults standardUserDefaults];
    var key         = TNArchipelHealthRefreshBaseKey + [_entity JID];
    if (![sender isOn])
    {
        if (_timerStats)
            [_timerStats invalidate];
        
        if (_timerLogs)
            [_timerLogs invalidate];
            
        [defaults setBool:NO forKey:key];
    }
    else
    {
        _timerStats = [CPTimer scheduledTimerWithTimeInterval:_timerInterval target:self selector:@selector(getHypervisorHealth:) userInfo:nil repeats:YES];
        _timerLogs  = [CPTimer scheduledTimerWithTimeInterval:_timerInterval target:self selector:@selector(getHypervisorLog:) userInfo:nil repeats:YES];
        
        [defaults setBool:YES forKey:key];
    }
}

// Modules implementation
- (void)willLoad
{
    [super willLoad];
    
    var center      = [CPNotificationCenter defaultCenter];
    var defaults    = [TNUserDefaults standardUserDefaults];
    var key         = TNArchipelHealthRefreshBaseKey + [_entity JID];
    
    [center addObserver:self selector:@selector(didNickNameUpdated:) name:TNStropheContactNicknameUpdatedNotification object:_entity];
    
    _memoryDatasource   = [[TNDatasourceGraphMemory alloc] init];
    _cpuDatasource      = [[TNDatasourceGraphCPU alloc] init];
    _loadDatasource     = [[TNDatasourceGraphLoad alloc] init];
    _disksDatasource    = [[TNDatasourceGraphDisks alloc] init];
    
    [_chartViewMemory setDataSource:_memoryDatasource];
    [_chartViewCPU setDataSource:_cpuDatasource];
    [_chartViewLoad setDataSource:_loadDatasource];
    [_chartViewDisk setDataSource:_disksDatasource];
    [_tableLogs setDataSource:_datasourceLogs]; 

    [self getHypervisorLog:nil];
    [self getHypervisorHealthHistory];
    
    [switchRefresh setOn:[defaults boolForKey:key] animated:YES sendAction:NO]; // not really a swicth..
    [self pauseRefresh:switchRefresh];
    
    [center postNotificationName:TNArchipelModulesReadyNotification object:self];
}

- (void)willUnload
{
    [super willUnload];

    if (_timerStats)
        [_timerStats invalidate];
    
    if (_timerLogs)
        [_timerLogs invalidate];

    [_cpuDatasource removeAllObjects];
    [_memoryDatasource removeAllObjects];
    [_loadDatasource removeAllObjects];
    [_disksDatasource removeAllObjects];
    [_datasourceLogs removeAllObjects];
}

- (void)willShow
{
    [super willShow];

    [fieldName setStringValue:[_entity nickname]];
    [fieldJID setStringValue:[_entity JID]];
}


- (void)didNickNameUpdated:(CPNotification)aNotification
{
    if ([aNotification object] == _entity)
    {
       [fieldName setStringValue:[_entity nickname]]
    }
}

- (void)getHypervisorHealth:(CPTimer)aTimer
{
    var stanza    = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildName:@"query" withAttributes:{"xmlns": TNArchipelTypeHypervisorHealth}];
    [stanza addChildName:@"archipel" withAttributes:{"xmlns": TNArchipelTypeHypervisorHealth, "action": TNArchipelTypeHypervisorHealthInfo}];
    
    [imageCPULoading setHidden:NO];
    [imageMemoryLoading setHidden:NO];
    [imageLoadLoading setHidden:NO];
    [imageDiskLoading setHidden:NO];
    
    [self sendStanza:stanza andRegisterSelector:@selector(didReceiveHypervisorHealth:)];
}

- (void)didReceiveHypervisorHealth:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var memNode = [aStanza firstChildWithName:@"memory"];
        var freeMem = Math.round(parseInt([memNode valueForAttribute:@"free"]) / 1024)
        var swapped = Math.round(parseInt([memNode valueForAttribute:@"swapped"]) / 1024);
        [healthMemUsage setStringValue:freeMem + " Mo"];
        [healthMemSwapped setStringValue:swapped + " Mo"];

        var diskNode = [aStanza firstChildWithName:@"disk"];
        var diskPerc = [diskNode valueForAttribute:@"used-percentage"];
        [healthDiskUsage setStringValue:diskPerc];

        var loadNode = [aStanza firstChildWithName:@"load"];
        var loadOne  = [loadNode valueForAttribute:@"one"];
        var loadFive = [loadNode valueForAttribute:@"five"];
        var loadFifteen = [loadNode valueForAttribute:@"fifteen"];
        [healthLoad setStringValue:loadFive];

        var uptimeNode = [aStanza firstChildWithName:@"uptime"];
        [healthUptime setStringValue:[uptimeNode valueForAttribute:@"up"]];

        var cpuNode = [aStanza firstChildWithName:@"cpu"];
        var cpuFree = 100 - parseInt([cpuNode valueForAttribute:@"id"]);
        [healthCPUUsage setStringValue:cpuFree + @"%"];

        var infoNode = [aStanza firstChildWithName:@"uname"];
        [healthInfo setStringValue:[infoNode valueForAttribute:@"os"] + " " + [infoNode valueForAttribute:@"kname"] + " " + [infoNode valueForAttribute:@"machine"]];

        [_cpuDatasource pushData:parseInt(cpuFree)];
        [_memoryDatasource pushDataMemUsed:parseInt([memNode valueForAttribute:@"used"])];
        
        [_loadDatasource pushData:parseFloat(loadOne * 1000) inSet:0];
        [_loadDatasource pushData:parseFloat(loadFive * 1000) inSet:1];
        [_loadDatasource pushData:parseFloat(loadFifteen * 1000) inSet:2];
            
        [_disksDatasource removeAllObjects];
        [_disksDatasource pushData:parseInt(diskPerc)];
        [_disksDatasource pushData:(100 - parseInt(diskPerc))];
        
        /* reload the charts view */
        [_chartViewMemory reloadData];
        [_chartViewCPU reloadData];
        [_chartViewLoad reloadData];
        [_chartViewDisk reloadData];
    }
    else if ([aStanza type] == @"error")
    {
        [self handleIqErrorFromStanza:aStanza];
    }
    
    [imageCPULoading setHidden:YES];
    [imageMemoryLoading setHidden:YES];
    [imageLoadLoading setHidden:YES];
    [imageDiskLoading setHidden:YES];
}


- (void)getHypervisorHealthHistory
{
    var stanza    = [TNStropheStanza iqWithType:@"get"];
    
    [stanza addChildName:@"query" withAttributes:{"xmlns": TNArchipelTypeHypervisorHealth}];
    [stanza addChildName:@"archipel" withAttributes:{
        "action": TNArchipelTypeHypervisorHealthHistory,
        "limit": _statsHistoryCollectionSize}];
    
    [imageCPULoading setHidden:NO];
    [imageMemoryLoading setHidden:NO];
    [imageLoadLoading setHidden:NO];
    [imageDiskLoading setHidden:NO];

    [self sendStanza:stanza andRegisterSelector:@selector(didReceiveHypervisorHealthHistory:)];
}

- (BOOL)didReceiveHypervisorHealthHistory:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var stats = [aStanza childrenWithName:@"stat"];
        stats.reverse();

        for (var i = 0; i < [stats count]; i++)
        {
            var currentNode = [stats objectAtIndex:i];

            var memNode = [currentNode firstChildWithName:@"memory"];
            var freeMem = Math.round(parseInt([memNode valueForAttribute:@"free"]) / 1024);
            var swapped = Math.round(parseInt([memNode valueForAttribute:@"swapped"]) / 1024);
            
            [healthMemUsage setStringValue:freeMem + " Mo"];
            [healthMemSwapped setStringValue:swapped + " Mo"];
            
            var cpuNode = [currentNode firstChildWithName:@"cpu"];
            var cpuFree = 100 - parseInt([cpuNode valueForAttribute:@"id"]);

            [healthCPUUsage setStringValue:cpuFree + @"%"];
            
            var loadNode = [currentNode firstChildWithName:@"load"];
            var loadOne = Math.round(parseFloat([loadNode valueForAttribute:@"one"]) * 1000);
            var loadFive = Math.round(parseFloat([loadNode valueForAttribute:@"five"]) * 1000);
            var loadFifteen = Math.round(parseFloat([loadNode valueForAttribute:@"fifteen"]) * 1000);
            
            
            [_cpuDatasource pushData:parseInt(cpuFree)];
            [_memoryDatasource pushDataMemUsed:parseInt([memNode valueForAttribute:@"used"])];
            [_loadDatasource pushData:parseInt(loadOne) inSet:0];
            [_loadDatasource pushData:parseInt(loadFive) inSet:1];
            [_loadDatasource pushData:parseInt(loadFifteen) inSet:2];
        }

        var maxMem = Math.round(parseInt([memNode valueForAttribute:@"total"]) / 1024 / 1024 )

        [fieldTotalMemory setStringValue: maxMem + "G"];
        [fieldHalfMemory setStringValue: Math.round(maxMem / 2) + "G"];
        [_chartViewMemory setFixedMaxValue: parseInt([memNode valueForAttribute:@"total"])];

        var diskNode = [aStanza firstChildWithName:@"disk"];
        [healthDiskUsage setStringValue:[diskNode valueForAttribute:@"used-percentage"]];
        
        /* reload the charts view */
        [_chartViewMemory reloadData];
        [_chartViewCPU reloadData];
        [_chartViewLoad reloadData];
        [_chartViewDisk reloadData];
    }
    else if ([aStanza type] == @"error")
    {
        [self handleIqErrorFromStanza:aStanza];
    }

    [imageCPULoading setHidden:YES];
    [imageMemoryLoading setHidden:YES];
    [imageLoadLoading setHidden:YES];
    [imageDiskLoading setHidden:YES];
    

    [self getHypervisorHealth:nil];

    if ([sender isOn])
    {
        /* now get health every 5 seconds */
        _timerStats = [CPTimer scheduledTimerWithTimeInterval:_timerInterval target:self selector:@selector(getHypervisorHealth:) userInfo:nil repeats:YES];
        _timerLogs  = [CPTimer scheduledTimerWithTimeInterval:_timerInterval target:self selector:@selector(getHypervisorLog:) userInfo:nil repeats:YES];
    }
    
    return NO;
}


- (void)getHypervisorLog:(CPTimer)aTimer
{
    var stanza    = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildName:@"query" withAttributes:{"xmlns": TNArchipelTypeHypervisorHealth}];
    [stanza addChildName:@"archipel" withAttributes:{
        "xmlns": TNArchipelTypeHypervisorHealth, 
        "action": TNArchipelTypeHypervisorHealthLog,
        "limit": _maxLogEntries}];
        
    [self sendStanza:stanza andRegisterSelector:@selector(didReceiveHypervisorLog:)];
}

- (void)didReceiveHypervisorLog:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var logNodes = [aStanza childrenWithName:@"log"];
        logNodes.reverse();
        
        [_datasourceLogs removeAllObjects];
        
        for (var i = 0; i < [logNodes count]; i++)
        {
            var currentLog  = [logNodes objectAtIndex:i];
            var lvl         = [currentLog valueForAttribute:@"level"];
            var date        = [currentLog valueForAttribute:@"date"];
            var file        = [currentLog valueForAttribute:@"file"];
            var method      = [currentLog valueForAttribute:@"method"];
            var message     = [currentLog text];
            var logEntry    = [TNLogEntry logEntryWithLevel:lvl date:date file:file method:method message:message];
            
            [_datasourceLogs addObject:logEntry];
        }
        [_tableLogs reloadData];

    }
    else if ([aStanza type] == @"error")
    {
        [self handleIqErrorFromStanza:aStanza];
    }

}


@end


