classdef data < dynamicprops % & event.source
    %DATA Holds data for a system, can be extended and linked to each other
    %   Using the dynamicprops, arbitrary fields can be added to an
    %   instance of this object. If another data object is created, a
    %   parent one can be provided and all fields that are not specifically
    %   set for the child data are received from the parent object.
    
    properties (SetAccess = protected, GetAccess = public)
        oParent;
        %tiEvents = struct(); % Store the ids for the 'change.*' events on the parent
        % Event ids for parent
        aiEvents = [ 0 0 ];
        
        % Attributes that where created locally in this data object (and
        % either don't exist in parent or are overloaded)
        % Also used for just check if prop exists, locally or not
        tbLocal = struct();
        
        % Struct holding the created properties
        toProps = struct();
    end
    
    methods
        function this = data(txData, oParent)
            % Constructor for data. Supports parameter shifting so the
            % txData parameter can be left out if not required.
            
            % Input arguments shift
            if nargin == 1 && isa(txData, 'data')
                oParent = txData;
                txData  = struct();
            elseif nargin < 2
                oParent = [];
            end
            
            this.setParent(oParent);
            
            if nargin >= 1 && ~isempty(txData)
                % Loop through data and add
                csKeys = fieldnames(txData);

                for iI = 1:length(csKeys)
                    this.set(csKeys{iI}, txData.(csKeys{iI}));
                end
            end
        end
        
        function set(this, sKey, xValue)
            % Sets the value for a specific attr and creates that attribute
            % if it doesn't exist yet. If the value is synced with parent,
            % deactivates that. If no value provided, syncing switched back
            % on if exists on parent, else just set to []
            
            % Preset xValue if not provided
            if nargin < 2, xValue = []; end
            
            
            % No value - check if exists in parent, activate syncing!
            if (nargin < 2) && ~isempty(this.oParent) && isfield(this.oParent.toProps, sKey)
                % Might be called from onParentChange and parent newly
                % created that property! addProp sets value.
                if ~isfield(this.toProps, sKey)
                    this.addProperty(sKey);
                
                % Local - switch to not local and update value
                elseif this.tbLocal.(sKey)
                    this.tbLocal.(sKey) = false;
                    this.(sKey) = this.oParent.(sKey);
                
                % Update value
                else
                    this.(sKey) = this.oParent.(sKey);
                end
                
            % New property? Add as local attr (even if value was not
            % provided - even if not local, would exist already!
            elseif ~isfield(this.toProps, sKey) %~any(strcmp(properties(this.oParent), sKey))
                this.addProperty(sKey, xValue);
            
            % Check if not local %and exists in parent% - stop syncronizing
            elseif ~this.tbLocal.(sKey) % && ~isempty(this.oParent) && isfield(this.oParent.tbLocal, sKey) %any(strcmp(properties(this.oParent), sKey))
                this.tbLocal.(sKey) = true;
                this.(sKey) = xValue;
                
            % Just set value
            else
                this.(sKey) = xValue;
            end
            
            
            % Trigger event
            % For now, inactive. Maybe replace with Matlab triggers?
            % Branch 'logging' needs this removed!
            %this.trigger([ 'change.' sKey ], struct('sKey', sKey, 'xValue', this.(sKey)));
        end
        
        function remove(this, sKey)
            % Removes property or, if parent set and property exists there,
            % switches back to sync with parent.
            
            % Check if property exists
            if ~isfield(this.toProps, sKey), return; end
            
            if ~isempty(this.oParent) && isfield(this.oParent.toProps, sKey) %any(strcmp(properties(this.oParent), sKey))
                % delete tbLocal, set parent value and trigger change!
                this.tbLocal.(sKey) = false;
                this.(sKey) = this.oParent.(sKey);
            else
                this.tbLocal = rmfield(this.tbLocal, sKey);
                %xOldValue    = this.(sKey);
                
                % Remove property meta object (deletes property) and entry
                % in the props struct
                delete(this.toProps.(sKey));
                
                this.toProps = rmfield(this.toProps, sKey);
                
                % For now, inactive. Maybe replace with Matlab triggers?
                % Branch 'logging' needs this removed!
                %this.trigger([ 'delete.' sKey ], struct('sKey', sKey, 'xOldValue', xOldValue));
            end
        end
        
        function xValue = get(this, sKey)
            xValue = this.(sKey);
        end
    end
    
    
    methods (Access = protected)
        
        function setParent(this, oParent)
            if ~isempty(this.oParent)
                % Remove events
                this.oParent.unbind(this.aiEvents(1));
                this.oParent.unbind(this.aiEvents(2));
                
                % Get parents keys
                csProps = fieldnames(this.oParent.tbLocal); %properties(this.oParent);
                
                % Remove parent
                this.oParent = [];
                
                % Remove props of parent in this obj if they're not local
                for iI = 1:length(csProps)
                    if ~this.tbLocal.(csProps{iI})
                        this.removeProperty(csProps{iI});
                    end
                end
            end
            
            if ~isempty(oParent)
                this.oParent = oParent;
                
                % Fires on all change.* as well!
                this.aiEvents(1) = this.oParent.bind('change', @this.onParentChange);
                this.aiEvents(2) = this.oParent.bind('delete', @this.onParentDelete);
                
                % Set properties
                csProps = fieldnames(this.oParent.tbLocal);
                
                for iI = 1:length(csProps)
                    % Only add prop if it doesn't exist yet - if it exists,
                    % its definitely local (no parent exists atm)
                    if ~isfield(this.toProps, csProps{iI})
                        this.addProperty(csProps{iI});
                    end
                end
            end
        end
        
        function addProperty(this, sKey, xVal)
            % Adds a property. If xVal is not provided and property exists
            % in parent, synced from there
            
            % xVal not provided - check if attr exists in parent
            if nargin < 3 && (isempty(this.oParent) || ~isfield(this.oParent.toProps, sKey)) %~any(strcmp(properties(this.oParent), sKey)))
                this.throw('addProperty', 'Property with no value added but parent not set or doesn''t have that property');
            end
            
            % Create property with set/get access
            this.toProps.(sKey) = this.addprop(sKey);
            this.toProps.(sKey).SetAccess = 'protected';
            
            % From parent or local
            if nargin < 3
                this.tbLocal.(sKey) = false;
                this.(sKey) = this.oParent.(sKey);
            else
                this.tbLocal.(sKey) = true;
                this.(sKey) = xVal;
            end
        end
        
        function onParentChange(this, oEvt)
            % Parent prop change - check for not local or if prop doesn't
            % yet exist and then call set()
            
            sKey = oEvt.tData.sKey;
            
            % Parent might have created that property just now, or the prop
            % is there and not local - call set without a value parameter
            % which then automatically adds the prop if necessary
            if ~isfield(this.toProps, sKey) || ~this.tbLocal.(sKey)
                this.set(sKey);
            end
        end
        
        function onParentDelete(this, oEvt)
            % If parent deletes a prop and its not local here, remove as
            % well!
            
            if ~this.tbLocal.(oEvt.tData.sKey)
                % Parent tbLocal already doesn't exist any more so deletes
                % the property
                this.removeProperty(oEvt.tData.sKey);
            end
        end
    end
    
	methods (Static)
        function this = loadobj(this)
            csProps = fieldnames(this.toProps);
            
            for iI = 1:length(csProps)
                this.toProps.(csProps{iI}).SetAccess = 'protected';
            end
        end
    end
end

