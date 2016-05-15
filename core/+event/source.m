classdef source < handle
    %EVENTS blah ...
    %
    %TODO
    %   - return obj when binding, just delete(obj) removes event bind?
    %   - clean of all stuff like time or ticks or anything specific -
    %     should be done with derived class or so
    %   - possibility to change the event object?
    %   - check each callback on registration with nargout(callBack), store
    %     the return. Then throw out the try/catch below!
    
    properties (Access = private)
        iCounter = 0;
        
        cxLastReturn = {};
        bNewLastReturn = false;
    end
    
    properties (SetAccess = private, GetAccess = public)
        tcEventCallbacks = struct();
        pcEventCallbacks;
        
        bHasCallbacks = false;
        
        tEventObject;
    end
    
    methods
        function this = source()
            this.pcEventCallbacks = containers.Map();
            
            
            this.tEventObject = struct(...
                'sType', [], ...
                'oCaller', this, ...
                'tData', [], ...
                ...
                ... %TODO IMPLEMENT - stop further execution of callbacks, 
                ... e.g. set this.tbStopCurrentEvent.(sType) = true
                ... 'stopPropagation', @(a, b) this.stopPropagation(sType), ...
                ...
                ... %TODO implement, allow callbacks to add return values
                ...   -> don't use real func outputs because Matlab stinks!
                ... 'cxReturn', {}, ...
                'addReturnValue', @this.addReturn ...
                ... addReturn would write xVal to this.xLastReturn, then 
                ... after each callbac execution below, check this.xLastRet
            );
            
        end
        
        % sType refers to event name, possibly hierachical (e.g.
        % schedule.exercise.bicycle); must not contain underscores
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            % Create struct for callback if it doesn't exist yet
            if ~this.pcEventCallbacks.isKey(sType), this.pcEventCallbacks(sType) = {}; end;
            
            
            cCallbacks = this.pcEventCallbacks(sType);
            cCallbacks{end + 1} = callBack;
            this.pcEventCallbacks(sType) = cCallbacks;
            
            this.bHasCallbacks = true;
            
            unbindCallback = @() this.unbind(sType, length(this.pcEventCallbacks(sType)));
        end
        
        
        function unbind(this, sType, iId)
            cCallbacks = this.pcEventCallbacks(sType);
            
            cCallbacks(iId) = [];
            
            this.pcEventCallbacks(sType) = cCallbacks;
        end
    end
    
    methods (Access = protected)
        
        
        function addReturn(this, xVal)
            %this.xLastReturn = xVal;
            %TODO cxLastReturn etc just if bRunning, see below!
            
            this.cxLastReturn{end + 1} = xVal;
            this.bNewLastReturn = true;
        end
        
        %CU uh! if e.g. tick.eat, and setTimeout, only executed while still
        %   on tick.eat - so at least a detick event, or something? JO!
        %   Then it is setTimeout OR detick!
        function cReturn = trigger(this, sType, tData)
            %global oSim;
            
            %TODO-SPEED why is that so slow? Find a way to speed up
            %           checking for existing events!
            %if isempty(this.pcEventCallbacks) || ~this.pcEventCallbacks.isKey(sType)
            if ~this.bHasCallbacks || ~this.pcEventCallbacks.isKey(sType)
                cReturn = {};
                return;
            end
%             try
%                 this.tcEventCallbacks.(sType);
%             catch oErr
%                 tReturn = struct();
%                 return;
%             end
            
            
            if nargin < 3, tData = []; end;
            
            % dbstack - get caller's function name and set for event obj?
            
            % FAKE OBJECT!
            %TODO-SPEED save on this.ttEventObjs.(sType) and reuse! Just
            %           overwrite tData/xData!
%             oEvent = struct(...
%                 'sType', sType, ...
%                 'oCaller', this, ...
%                 'xData', tData, ...
%                 'tData', tData, ...
%                 ...
%                 ... %TODO IMPLEMENT - stop further execution of callbacks, 
%                 ... e.g. set this.tbStopCurrentEvent.(sType) = true
%                 ... 'stopPropagation', @(a, b) this.stopPropagation(sType), ...
%                 ...
%                 ... %TODO implement, allow callbacks to add return values
%                 ...   -> don't use real func outputs because Matlab stinks!
%                 ... 'cxReturn', {}, ...
%                 'addReturnValue', @this.addReturn ...
%                 ... addReturn would write xVal to this.xLastReturn, then 
%                 ... after each callbac execution below, check this.xLastRet
%             );

            % Copy from default event obj
            oEvent = this.tEventObject;
            
            oEvent.sType = sType;
            oEvent.tData = tData;
            
            
            
            
            cCallbackCell = this.pcEventCallbacks(sType);
            cReturn = cell(1, length(cCallbackCell));
            
            
            for iC = 1:length(cCallbackCell)
                callBack = cCallbackCell{iC};
                
%                 % Execute callback - first try with return
%                 try
%                     cReturn{iC} = callBack(oEvent);
%                     
%                     %if ~isempty(xTmp), cReturn.(sprintf('cb_%i', iC)) = xTmp; end;
% 
%                 % Ok, that didn't work, so now without return
%                 % STUPID MATLAB!
%                 %catch
%                 %    callBack(oEvent);
%                 %end
%                 catch oErr
%                     % If error is not 'Too many output 
%                     % arguments' or 'undefined func', throw!
%                     csErrorIdentifiers = {'MATLAB:TooManyOutputs',...
%                                           'MATLAB:maxlhs',...
%                                           'MATLAB:UndefinedFunction'};
% 
%                     if ~any(strcmp(oErr.identifier, csErrorIdentifiers))
%                         rethrow(oErr);
%                     else
                        callBack(oEvent);
                        
                        %TODO todo do cxLastReturn stuff only if nested
                        %     events? cath that -> bRunning, then if event
                        %     triggered again and bRunning -> nested!
                        if this.bNewLastReturn % ~isempty(this.xLastReturn)
                            cReturn{iC} = this.cxLastReturn{end};
                            
                            this.cxLastReturn(end) = {};
                            
                            if isempty(this.cxLastReturn)
                                this.bNewLastReturn = false;
                            end
                            %this.xLastReturn = [];
                        end
%                     end
%                 end
            end
        end
    end
end