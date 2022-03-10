function [chnData, evnt] = INVOSoutputParser(invosLog,chnNums)
% Reads logs written by INVOSstreamer.
% 
% Usage:
% [chnData, evnt] = INVOSoutputParser(invosLog [,chnNums])
%
% INPUT:
%   invosLog - log text file from INVOSstreamer
%   chnNums  - optional, channel indices to read, defaults to [1 2]. INVOS
%               provides up to 4 channels.
%
% OUTPUT:
%   chnData  - Structure containing the main data, each row represents a
%               sample trasmitted by the INVOS, colums correspond to
%               chnNums.
%               - t_pc      date-time-stamp of computer on which
%                           INVOSstreamer run (serial datenumber).
%               - t_invos   date-time-stamp of INVOS (serial datenumber).
%               - Columns transmitted by INVOS for each channel:
%                   'chName', 'rSO2', 'Evnt', 'Status', 'Baseline', 'AUC',
%                   'UAL' (upper alarm limit), 'LAL' (lower alarm limit) 
%               Note that the INVOS can output data in two formats and
%               format #2 does not contain all of the above columns. In
%               that case the corresponding values are set to NaN.
%   evnt     - Structure containing external events (captured by
%               INVOSstreamer, e.g. Triggers)
%               - t_pc      date-time-stamp of computer on which
%                           INVOSstreamer run (serial datenumber).
%               - event      Name of event
%               - eventData Additional data of the event. In case of
%                           lsl-triggers sent by Aurora, this includes an
%                            - lsl(?)-timestamp,
%                            - the current duration of the measurement in
%                              seconds and
%                            - the trigger number


% CONSTANTS ...............................................................
EVNT_NAMES = {'TRIGGER', 'INVOS_started', 'RECORDING_started', 'RECORDING_stopped'};
INVOS_STATUS = {
        0 'NO STATUS';
        1 'SENSOR NOT CONNECTED';
        2 'CHECK SENSOR';
        3 'POOR SIGNAL QUALITY';
        4 'SYSTEM SIGNAL OK';
        5 'rSO2 HIGH';
        6 'rSO2 LOW';
        11 'PRE-AMP NOT CONNECTED';
        17 'REPLACE SENSOR';
        19 'FAILURE DETECTED';
        21 'AUTO BASELINE SET';
        };


COL_NAMS.init =    {'chName', 'rSO2', 'Evnt', 'Status', 'Baseline', 'AUC', 'UAL', 'LAL'};
COL_DTYPE     =    {'char',   'num',  'num',  'num',    'num',      'num', 'num', 'num'};
COL_NAMS.format1 = {'chName', 'rSO2', 'Evnt', 'Status', 'Baseline', 'AUC', 'UAL', 'LAL'};
NUMCOLS.format1 = 11;
C0.format1 = 2;
COL_NAMS.format2 = {'rSO2', 'Evnt', 'Status'};
%                    'num',  'num',  'num'};
NUMCOLS.format2 = 7;
C0.format2 = 1;


% CHECK INPUT, PREP OUTPUT  ...............................................
if nargin<2 % || isempty(chnNums) % ~exist('chnNums','var')
    chnNums = 1:2;
else
    chnNums = chnNums(:).';
end
nChn = numel(chnNums);

evnt = struct('t_pc',[],'event',{{}},'eventData',{{}});
flds = [COL_NAMS.init; repmat({{{}}},1,numel(COL_NAMS.init))];
chnData = struct(flds{:});


% OPEN LOG FILE ...........................................................
[fid,err] = fopen(invosLog,'r');
assert(fid>-1,'Failed to open file\n ''%s''\n%s',invosLog,err);

tline = fgetl(fid);
ln = 0;
lnFile = 0;

% LOOP LINES ..............................................................
while ischar(tline)
    cols = strsplit(tline, ' ');
    lnFile = lnFile + 1;
    
    % ignore empty line
    if all(cellfun(@isempty,cols))
        tline = fgetl(fid);
        continue;
    end
    
    % get computer time stamp
    try
        t_pc = datenum(cols{1},'yyyy-mm-dd_HH-MM-SS');
    catch ME
        baseME = MException('INVOSoutputParser:unrecognizedLine',...
                'Failed to parse line #%d:\n %s',lnFile, tline);
        throw(baseME.addCause(ME));
    end
    
    % check line type:
    if ismember(cols{2},EVNT_NAMES)
       % EVENT ............................................................
       evnt.t_pc(end+1,1) = t_pc;
       evnt.event{end+1,1} = cols{2};
       if numel(cols)>2
           evnt.eventData{end+1,1} = cols(3:end);
       else
           evnt.eventData{end+1,1} = {};
       end
       
    else % DATA ...........................................................
        ln = ln+1;
        if ~isempty(regexp(cols{2},'(\d\d/){2}\d\d','once'))
            % DATA FORMAT 2
            fmt = 'format2';
            
        elseif ~isempty(regexp(cols{2},'(\d+\.)*(\d+/)*\d','once'))
            % DATA FORMAT 1
            fmt = 'format1';
            
        else
            % catch unrecognized line
            error('INVOSoutputParser:unrecognizedLine',...
                'Failed to parse line #%d:\n %s',lnFile,tline);
        end

        t_invos = strjoin(cols((1:2)+C0.(fmt)),' ');
        chnData.t_invos(ln,1) = datenum(t_invos,'mm/dd/yy HH:MM:SS');
        chnData.t_pc(ln,1) = t_pc;
        
        for chIdx = 1:nChn
            ciOffset = C0.(fmt) + 2 + (chnNums(chIdx)-1)*NUMCOLS.(fmt);
            for ci = 1:size(COL_NAMS.init,2)
                var = COL_NAMS.init{1,ci};
                [isFld,locFld] = ismember(var, COL_NAMS.(fmt));
                if isFld
                    chnData.(var){ln,chIdx} = cols{ciOffset+locFld};
                else
                    chnData.(var){ln,chIdx} = '';
                end
            end
        end
    end
    
    tline = fgetl(fid);
end

idxConvert = find(strcmp(COL_DTYPE,'num'));
for k = idxConvert
    chnData.(COL_NAMS.init{k}) = str2double(chnData.(COL_NAMS.init{k}));
end

chnData.StatusMsg = repmat({'UNKNOWN'},size(chnData.Status));
[k,stsIdx] = ismember(chnData.Status, vertcat(INVOS_STATUS{:,1}));
chnData.StatusMsg(k) = INVOS_STATUS(stsIdx(k),2);
end

