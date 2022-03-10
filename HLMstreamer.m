classdef HLMstreamer < A_SERIAL_STREAMER
    
    
    properties
        SerialPortParam = {9600, ... BAUDRATE
                            'Parity',       'none', ...         default: none
                            'DataBits',     7, ...              default: 8
                            'StopBits',     1, ...              default: 1
                            'FlowControl',  'none', ...         default: none
                            'ByteOrder',    'little-endian', ...'big-endian', ... default: little-endian
                            'Timeout',      1 ...              default: 10
                            };
        SerialPortTerminator = 3;
    end
    
    properties (Constant)
        DEVICENAME = 'HLM';
    end
    
    
    %% METHODS
    
    methods (Access = public)
        
        function scomCallback(app,src,~)
            nlOut = 0;
            data = {}; tstmp = {};
            while src.NumBytesAvailable > HLMstreamer.MinBytesPerLine
                try
                    d = char(src.readline());
                catch ME
                    app.setStatus('error');
                    app.setStatusMsg('Error while reading data from serial port.');
                    figure(app.SuperStreamerUIFigure);
                    uialert(app.SuperStreamerUIFigure, ...
                        sprintf('There was an error while reading serial port.\nSee command line for further details.'), ...
                        'Error while receiving data');
                    rethrow(ME);
                end
                if ~isempty(d)
                    data{end+1} = regexprep(d, {char(31), char(2)}, ...
                                               {'; ',     char(9)});
                    tstmp{end+1} = HLMstreamer.TimeStamp();
                    nlOut = nlOut + 1;
                else, break;
                end
            end
            if nlOut>0
                try
                    app.saveData(data,tstmp,2);
                catch ME
                    app.setStatus('error');
                    app.setStatusMsg('Error while saving serial port data.');
                    figure(app.SuperStreamerUIFigure);
                    uialert(app.SuperStreamerUIFigure, ...
                        sprintf('There was an unhandled error while saving serial port data.\nSee command line for further details.'), ...
                        'Error while saving data');
                    rethrow(ME);
                end
                app.TimeLastDataStored = now;
            end
        end

    end % methods public

end