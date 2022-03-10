function [sOut,nLnErr,lnIdxErr,lnStrErr] = HLMoutputParser(hlmOutFile)
%
% V 1.0, Konrad Schumacher, 2022

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

% strctInit = [VIDs.Variable.'; cell(1,size(VIDs,1))]; 
% dOut = struct(strctInit{:},'TRIGGER',[],'RECORDING_started',[],'RECORDING_stopped',[]);
varNames = [VIDs.Variable.', 'TRIGGER', 'RECORDING_started', 'RECORDING_stopped'];
dOut = cell(size(varNames));
nIDs = numel(varNames);
vidsArr = [vidsArr;nan(abs([nIDs 0] - size(vidsArr)))];

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
%             vNam = mtch{2};
            idIdx = strcmp(varNames,mtch{2});
            if startsWith(mtch{2},'RECORDING')
                data = [];
            else
                data = str2double(mtch(3:end));
            end
%             t = convertTStmp(mtch{1});
        end
        
        
    else % save HLM data:
%         t = convertTStmp(mtch{1});
        fulldata = str2double(mtch(2:end));
        idIdx = all(bsxfun(@eq,fulldata(1:3),vidsArr),2);
%         idIdx = all(strcmp(repmat(mtch(2:4),nIDs,1),vidsArrCS),2);
        if ~any(idIdx) % don't know this ID
            tline = fgetl(fid);
            continue;
        end
%         vNam = VIDs.Variable{idIdx};
        
%         data = mtch(5:6);
        if fulldata(5) == 17
            data = fulldata(4)/86400;
        elseif fulldata(5) == 18
            data = .5 + fulldata(4)/86400;
        else
            data = fulldata(4:5);
        end
    end
    
%     outIdx = strcmp(varNames,vNam);
%     assert(sum(outIdx)==1,'HLMoutputParser:VarNameError','Unexpected variable name ''%s''.',varNames{idIdx});
    dOut{idIdx}(end+1,:) = {mtch{1} data};
    
    tline = fgetl(fid);
end

fclose(fid);
if nVarOut<2 && nLnErr>0
    warning('HLMoutputParser:UnrecognizedLines',...
        'Failed to parse %d lines (out of %d) in file %s!', nLnErr, lnNum, hlmOutFile);
end

% iConvert = cellfun(@(x)size(x,2)>1,dOut);
% dOut(iConvert) = cellfun(@(x)[convertTStmp(x(:,1)) str2double(x(:,2:end))],...
%     dOut(iConvert),'UniformOutput',false);

% for k = find(iConvert)
%     i18 = dOut{k}(:,3) == 18; % PM
%     dOut{k}(i18,2:3) = [dOut{k}(i18,2) + 43200, 17]; % add 1/2 day
% end

% iConvert = xor(iConvert,~cellfun(@isempty,dOut));
iConvert = ~cellfun(@isempty,dOut);
% dOut(iConvert) = cellfun(@(x)convertTStmp(x),...
%     dOut(iConvert),'UniformOutput',false);
dOut(iConvert) = cellfun(@(x)[convertTStmp(x(:,1)) cell2mat(x(:,2))],...
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
