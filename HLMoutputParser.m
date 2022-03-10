function [sOut,nLnErr,lnIdxErr,lnStrErr] = HLMoutputParser(hlmOutFile)
%
% V 1.1, Konrad Schumacher, 2022

VARIDFILE = fullfile(fileparts(mfilename('fullpath')),'HLMvariableIDs.csv');
try
    VIDs = readtable(VARIDFILE);
catch ME
    throw(addCause(MException('HLMoutputParser:failedToReadVarIDs', ...
        'Failed to load IDs of HLM variables.'),ME));
end

[fid,msg] = fopen(hlmOutFile,'r');
if fid<0, error('HLMoutputParser:failedToOpenFile',...
        'Failed to open hlm-output file for reading. Reason:\n%s',...
        msg);
end

nVarOut = nargout;
DTimePattrn = '(^\d{4}-\d\d-\d\d_\d\d-\d\d-\d\d(?:\.\d{3})?)'; % 1 token
HLMdataPattrn = strjoin(repmat({'(-?[\d\.]+)'},1,6),';\\s*'); % 6 token
TrgRecPattrn = '(TRIGGER|RECORDING_\w+)\s*(\d+\.\d+)?\s*(\d+)?'; % 3 token

vidsArr = table2array(VIDs(:,2:4));
assert(size(vidsArr,1) == size(unique(vidsArr,'rows'),1), ...
    'HLMoutputParser:invalidVarIDs', 'There is a duplicated ID in %s!', VARIDFILE);

varNames = [VIDs.Variable.', 'TRIGGER', 'RECORDING_started', 'RECORDING_stopped'];
dOut = cell(size(varNames));
nIDs = numel(varNames);
vidsArrCS = compose('%d',[vidsArr;nan(abs([nIDs 0] - size(vidsArr)))]);

lnIdxErr = [];
nLnErr = 0;
lnStrErr = {};
tline = fgetl(fid);
lnNum = 0;

while ischar(tline)
    lnNum = lnNum + 1;
    mtch = regexp(tline,sprintf('%s\\s+%s',DTimePattrn,HLMdataPattrn),'tokens','once');
   
    
    if isempty(mtch)
        mtch = regexp(tline,sprintf('%s\\s+%s',DTimePattrn,TrgRecPattrn),'tokens','once');
        
        if isempty(mtch) % parsing line failed !
            if ~isempty(tline) % report failure if line was not empty:
                if nVarOut > 3, lnStrErr = [lnStrErr {tline}]; end
                if nVarOut > 2, lnIdxErr = [lnIdxErr; lnNum]; end
                nLnErr = nLnErr + 1;
            end
            tline = fgetl(fid);
            continue;
            
        else % save TRG / REC start/stop:
            idIdx = strcmp(varNames,mtch{2});
            if startsWith(mtch{2},'RECORDING')
                data = [];
            else
                data = mtch(3:end); % str2double(mtch(3:end));
            end
        end
        
        
    else % save HLM data:
        idIdx = all(strcmp(repmat(mtch(2:4),nIDs,1),vidsArrCS),2);
        if ~any(idIdx) % don't know this ID
            tline = fgetl(fid);
            continue;
        end
        
        data = mtch(5:6);
    end
    
    dOut{idIdx}(end+1,:) = [mtch(1) data];
    
    tline = fgetl(fid);
end

fclose(fid);
if nVarOut<2 && nLnErr>0
    warning('HLMoutputParser:UnrecognizedLines',...
        'Failed to parse %d lines (out of %d) in file %s!', nLnErr, lnNum, hlmOutFile);
end

iConvert = cellfun(@(x)size(x,2)>1,dOut);
dOut(iConvert) = cellfun(@(x)[convertTStmp(x(:,1)) str2double(x(:,2:end))],...
    dOut(iConvert),'UniformOutput',false);

for k = find(iConvert)
    i18 = dOut{k}(:,3) == 18; % PM
    dOut{k}(i18,2:3) = [dOut{k}(i18,2) + 43200, 17*ones(sum(i18),1)]; % add 1/2 day
end

iConvert = xor(iConvert,~cellfun(@isempty,dOut));
dOut(iConvert) = cellfun(@(x)convertTStmp(x),...
    dOut(iConvert),'UniformOutput',false);


sOut = cell2struct(dOut,varNames,2);

end


function t = convertTStmp(tchar)
% for datetime():
% TStmpFrmt = {'yyyy-MM-dd_HH-mm-ss.SSS','yyyy-MM-dd_HH-mm-ss'}; 
% for datenum():
TStmpFrmt = {'yyyy-mm-dd_HH-MM-SS.FFF','yyyy-mm-dd_HH-MM-SS'};
validateattributes(tchar,{'char' 'cell'},{'2d'});

for k = 1:numel(TStmpFrmt)
    try
        t = datenum(tchar,TStmpFrmt{k});
        break;
    catch ME
    end
end
if ~exist('t','var')
    throw(addCause(MException('HLMoutputParser:failedToConvertTimeStmp',...
        'Failed to convert time stamp!'),ME));
end
end
