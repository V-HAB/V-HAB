classdef source < handle
    %SOURCE provides the framework for other classes to use events. 
    % If any class wants to use .bind or .trigger functions it has to
    % inherit from this class! For documentation regarding events visit:
    % https://wiki.tum.de/pages/viewpage.action?pageId=41593225
    
    % These properties are only used internally and should not be
    % changeably by child classes, so their SetAccess is private.
    properties (SetAccess = private, GetAccess = public)
        % A struct containing cells with one cell per trigger. The cells
        % then contain all of the actual callbacks for each trigger. 
        tcEventCallbacks = struct();
        
        % A boolean variable indicating if the object that derives from
        % this class has callbacks at all. This is a performance measure,
        % so we don't have to do all of the stuff in trigger() only to find
        % out, there's nothing to do. 
        bHasCallbacks = false;
        
        % A struct containing the information for a default, empty event.
        % Must be initialized in the constructor.
        tDefaultEvent;
    end
    
    methods
        
        function this = source()
            % Initializing the default, empty event object. 
            this.tDefaultEvent = struct(...
                'sType', [], ...
                'oCaller', this, ...
                'tData', [] ...
                );
            
        end
        
        function [ this, hUnbindCallback ] = bind(this, sName, hCallBack)
            %BIND Binds a function handle to the event with the given name
            % sName cen be hierachical (e.g. schedule.exercise.bicycle);
            % must not contain underscores
        
            % Create struct entry for callback if it doesn't exist yet
            if ~isfield(this.tcEventCallbacks, sName)
                this.tcEventCallbacks.(sName) = {};
            end
            
            % Adding the callback to the struct entry
            this.tcEventCallbacks.(sName){end+1} = hCallBack;
            
            % Setting the bHasCallbacks property to true
            this.bHasCallbacks = true;
            
            % Returning the unbind callback
            iCallBack = length(this.tcEventCallbacks.(sName));
            hUnbindCallback = @() this.unbind(sName, iCallBack);
            
        end
        
        function unbind(this, sName, iId)
            %UNBIND Removes a callback from this object
            % The name and ID of the callback to be removed is generated
            % automatically in the bind() method and passed back to the
            % binding entity. 
            this.tcEventCallbacks.(sName)(iId) = [];
        end
        
        function unbindAllEvents(this)
            % this function can be used to unbind all callbacks that the
            % current object had registered. This is helpfull for example
            % if something like a manipulator is detached from a phase and
            % then moved somewhere else. In that case removing all
            % callbacks makes sense, as most likely everything for the
            % object has changed. If any callback should still be present,
            % it must be readded afterwards
            this.tcEventCallbacks = struct();
        end
    end
    
    methods (Access = protected)
        % The trigger method is protected so only the objects that derive
        % from this class can call it themselves and not some random object
        % from the outside.
        
        function trigger(this, sName, tData)
            %TRIGGER Triggers the exection of all callbacks registered to the event called sName
            
            % If there are no callbacks associated with this object, we can
            % just return without doing anything. 
            if ~this.bHasCallbacks
                return
            end            
            
            % If no data struct is given, we set the local variable to
            % empty. 
            if nargin < 3, tData = []; end
            
            % Copy struct from default event
            tEvent = this.tDefaultEvent;
            
            % Setting the name of the event
            tEvent.sType = sName;
            
            % Setting the data payload
            tEvent.tData = tData;
            
            % It may be that this object has callbacks, but not necessarily
            % for the exact trigger being executed here. So we check if
            % there is even a field with the trigger name and only then do
            % we get the cell with callbacks. 
            try
                cCallbackCell = this.tcEventCallbacks.(sName);
            catch
                return
            end
            
            % Last thing to do here is to loop through all of the callbacks
            % and actually execute them. 
            for iC = 1:length(cCallbackCell)
                cCallbackCell{iC}(tEvent);
                
            end
            
        end
    end
end