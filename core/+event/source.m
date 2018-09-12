classdef source < handle
    % provides the framework for other classes to use events. If any class
    % wants to use .bind or .trigger functions it has to inherit from this
    % class! For documentation regarding events visit:
    % https://wiki.tum.de/pages/viewpage.action?pageId=41593225
    
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
                'addReturnValue', @this.addReturn ...
            );
            
        end
        
        % sType refers to event name, possibly hierachical (e.g.
        % schedule.exercise.bicycle); must not contain underscores
        function [ this, unbindCallback ] = bind(this, sType, callBack)
            % Create struct for callback if it doesn't exist yet
            if ~isfield(this.tcEventCallbacks, sType)
                this.tcEventCallbacks.(sType) = {};
            end
            
            this.tcEventCallbacks.(sType){end+1} = callBack;
            
            this.bHasCallbacks = true;
            
            unbindCallback = @() this.unbind(sType, length(this.tcEventCallbacks.(sType)));
        end
        
        
        function unbind(this, sType, iId)            
            this.tcEventCallbacks.(sType)(iId) = [];
        end
    end
    
    methods (Access = protected)
        
        
        function addReturn(this, xVal)
            this.cxLastReturn{end + 1} = xVal;
            this.bNewLastReturn = true;
        end
        
        function cReturn = trigger(this, sType, tData)
            
            if ~this.bHasCallbacks
                cReturn = {};
                return;
            end            
            
            if nargin < 3, tData = []; end
            
            % Copy from default event obj
            oEvent = this.tEventObject;
            
            oEvent.sType = sType;
            oEvent.tData = tData;
            
            try
                cCallbackCell = this.tcEventCallbacks.(sType);
            catch
                cReturn = {};
                return;
            end
            
            cReturn = cell(1, length(cCallbackCell));
            
            for iC = 1:length(cCallbackCell)
                callBack = cCallbackCell{iC};
                
                callBack(oEvent);
                
                if this.bNewLastReturn
                    cReturn{iC} = this.cxLastReturn{end};

                    this.cxLastReturn(end) = {};

                    if isempty(this.cxLastReturn)
                        this.bNewLastReturn = false;
                    end
                end
            end
        end
    end
end