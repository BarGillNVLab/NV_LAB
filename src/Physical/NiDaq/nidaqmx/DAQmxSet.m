function status = DAQmxSet(task, what, channel, SetTo)

    DAQmxGet(task, what, channel); % Setting doesn't always work without this line, don't know why!
    
switch what
    case 'CIPulseWidth.DigFltrTimebaseSrc'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCIPulseWidthDigFltrTimebaseSrc(task,channel, SetTo);
    case 'CI.CtrTimebaseSrc'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCICtrTimebaseSrc(task,channel, char(SetTo));
    case 'CI.DupCountPrevent'
        [status] = daq.ni.NIDAQmx.DAQmxSetCIDupCountPrevent(task, channel, uint32(SetTo)  );
    case 'CI.PulseWidthTerm'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCIPulseWidthTerm(task, channel, SetTo  );
    case 'CICountEdgesTerm'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCICountEdgesTerm(task, channel, SetTo  );
    case 'DigLvlPauseTrigSrc'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetDigLvlPauseTrigSrc(task,SetTo);
    case 'DigLvlPauseTrigWhen'
        [status] = daq.ni.NIDAQmx.DAQmxSetDigLvlPauseTrigWhen(task,SetTo);
    case 'CO.PulseTerm'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCOPulseTerm(task,channel,SetTo);               
    case 'Something'
        
    %%%%%
    case 'CI.CountEdgesTerm'
        [status, SetTo] = daq.ni.NIDAQmx.DAQmxSetCICountEdgesTerm(task,channel,SetTo);
    case 'PauseTrigType'
        [status] = daq.ni.NIDAQmx.DAQmxSetPauseTrigType(task,SetTo);     
    case 'Retrigger'
        [status] = daq.ni.NIDAQmx.DAQmxSetStartTrigRetriggerable(task,SetTo);
        
    %%%%%
    otherwise
end
end