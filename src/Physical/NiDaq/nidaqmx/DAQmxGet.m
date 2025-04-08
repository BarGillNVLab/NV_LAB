function [status, result] = DAQmxGet(task, what, channel)
strData = blanks(32);
strDataSize = uint32(32);
intData = int32(0);
bData = uint32(0);
switch what
    case 'CI.PulseWidth.DigFltrTimebaseSrc'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCIPulseWidthDigFltrTimebaseSrc(task,channel, strData, strDataSize);
    case 'CI.CountEdges.CtrTimebaseSrc'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCICountEdgesCountDirDigFltrTimebaseSrc(task,channel, strData, strDataSize);
    case 'CI.CtrTimebaseSrc'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCICtrTimebaseSrc(task,channel, strData, strDataSize);
    case 'CI.PulseWidthTerm'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCIPulseWidthTerm(task,channel, strData, strDataSize);
    case 'ChanType'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetChanType(task,channel, intData);
    case 'ChanDescr'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetChanDescr(task,channel, strData, strDataSize);
    case 'CI.DupCountPrevent'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCIDupCountPrevent(task, channel, bData);
    case 'CO.PulseTerm'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetCOPulseTerm(task,channel, strData, strDataSize);
    %%%
    case 'CI.CountEdgesTerm'
       [status, result] = daq.ni.NIDAQmx.DAQmxGetCICountEdgesTerm(task,channel, strData, strDataSize);
    case 'PauseTrigType' 
       [status, result] = daq.ni.NIDAQmx.DAQmxGetPauseTrigType(task,intData);
    case 'DigLvlPauseTrigSrc'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetDigLvlPauseTrigSrc(task,strData,strDataSize);
    case 'DigLvlPauseTrigWhen'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetDigLvlPauseTrigWhen(task,intData);
    case 'Retrigger'
        [status, result] = daq.ni.NIDAQmx.DAQmxGetStartTrigRetriggerable(task, bData);
        
    %%%
    otherwise
        error('%s is not defined', what);
end