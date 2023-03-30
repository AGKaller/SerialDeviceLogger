classdef NEUROSstreamer < A_SERIAL_STREAMER
    
    % TODO: Check, revise scomCallback!
    
    properties
        SerialPortParam = {9600, 'Timeout',1};
        SerialPortTerminator = [];
        SampleRate = .1;
    end
    
    properties (Constant)
        DEVICENAME = 'NeurOS';
    end
   

    %% METHODS
    
    methods (Access = public)
          
        function scomCallback(app,src,~)
            nlOut = 0;
            data = {}; tstmp = {};
            while src.NumBytesAvailable > NEUROSstreamer.MinBytesPerLine
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
                if ~isempty(d)
                    d = regexprep(d,'\n|\r','');
                    d = strtrim(d);
                    if ~isempty(d)
                        data{end+1} = d;
                        tstmp{end+1} = NEUROSstreamer.TimeStamp();
                        nlOut = nlOut + 1;
                    end
                else, break;
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

    end % methods public

end