classdef console_run < handle
%CONSOLE_RUN executes scripts and controls Matlab
%
% Except for the logging feature - IGNORE.
%
% Executes Matlab scripts and displays control string when finished,
% provides ... not that much right now.
%


    properties (SetAccess = protected, GetAccess = public)
        % Object to register callback on
        oRef;
        
        % Event to bind to
        sEvent;
        
        % Skip calls, e.g. 100 --> only pause every 100th call
        iSkip = 0;
    end
    
    methods
        function this = console_run(oRef, sEvent, iSkip)
            this.oRef = oRef;
            this.sEvent = sEvent;
            
            if nargin >= 3, this.iSkip = iSkip; end
            
            this.oRef.bind(this.sEvent, @this.checkInput);
        end
        
    end
    
    methods (Access = protected)
        function checkInput(this, oEvt)
            %TODO
            % Check console input? Socket?
        end
    end
    
    
    methods (Static = true, Access = public)
        function sRtn = executeScript(sScript)
            %disp('>>>>>>>>>>> MATLAB SCRIPT OBJ <<<<<<<<<<<<<<<');
            %disp();
            evalin('base', strrep(sScript, '\n', sprintf('\n')));
            disp('>>{done}<<');

            sRtn = evalin('base', 'sMatlabScriptReturn');
        end
        
        function toObject(sUri, sKey, sData)
            pParams = tools.JSON.load([ '{ "params": ' sData '}' ]);
            xParams = pParams('params');
            oObj    = base.getObj(sUri);
            
            
            if any(strcmp({ oObj.oMeta.MethodList.Name }, sKey))
                try
                    if isempty(xParams)
                        oObj.(sKey)(xParams);
                        
                    elseif iscell(xParams)
                        oObj.(sKey)(xParams{:});
                        
                    else
                        oObj.(sKey)(xParams);
                    end
                catch oErr
                end
                
            else
                oObj.(sKey) = xParams;
                %disp(oObj.oHuman.tState.tCurr);
                
            end
            
            disp('>>{done}<<');
            
            
            %pause(1);
            %disp('################# toObject #######################');
            %disp(sUri);
            %disp(sKey);
            %disp(sData);
            %disp(isempty(xParams));
            %disp(base.getObj(sUri));
            %disp('################# /toObject #######################');
        end
    end
end

