classdef SonoTTstreamer < A_SERIAL_STREAMER
    
    
    properties
        SerialPortParam = {57600, ... BAUDRATE
                            'Parity',       'none', ...         default: none
                            'DataBits',     8, ...              default: 8
                            'StopBits',     1, ...              default: 1
                            'FlowControl',  'none', ...         default: none
                            'ByteOrder',    'little-endian', ...'big-endian', ... default: little-endian
                            'Timeout',      1 ...              default: 10
                            };
        SerialPortTerminator = "CR/LF";
        SampleRate = .05; % actually .025?

    end
    
    properties (Constant)
        DEVICENAME = 'SonoTT';
        paramMatch = '(..) (..) (..) ([\+\-]\d\d)(\d{3}) 0{0,2}(\d{1,3})';
        paramReplace = '$1;0x$2;0x$3;$4,$5;$6%'; % Output format
    end


    %% METHODS
    
    methods (Access = public)
        
        function scomCallback(app,src,~)
            nlOut = 0;
            data = {}; tstmp = {};
            while src.NumBytesAvailable > app.MinBytesPerLine
                try
                    d = char(src.readline());
                catch ME
                    app.setStatus('error');
                    app.setStatusMsg('Error while reading data from serial port.');
                    figure(app.SerialStreamerUIFigure);
                    uialert(app.SerialStreamerUIFigure, ...
                        sprintf('There was an error while reading serial port.\nSee command line for further details.'), ...
                        'Error while receiving data');
                    rethrow(ME);
                end

                if ~isempty(d) && strcmp(d(1),'Q')
                    % FILL CACHE TO BE WRITTEN TO FILE 
                    data{end+1} = regexprep(d, app.paramMatch, app.paramReplace, 'once');
                    tstmp{end+1} = app.TimeStamp();
                    nlOut = nlOut + 1;
                elseif ~isempty(d) && strcmp(d(1),'M')
                    % PLOT 3s-AVERAGE
                    ... TODO!
                end
            end
            if nlOut>0
                try
                    app.saveData(data,tstmp,2);
                catch ME
                    app.setStatus('error');
                    app.setStatusMsg('Error while saving serial port data.');
                    figure(app.SerialStreamerUIFigure);
                    uialert(app.SerialStreamerUIFigure, ...
                        sprintf('There was an unhandled error while saving serial port data.\nSee command line for further details.'), ...
                        'Error while saving data');
                    rethrow(ME);
                end
                app.TimeLastDataStored = now;
            end
        end
    end
end