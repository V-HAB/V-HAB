classdef Capacity < base
    %CAPACITY An object that holds thermal energy
    %   This is a wrapper class for querying properties of matter objects.
    
    % TODO: 
    %   - support (F2F) PROCs / EXMEs? or do it in transfers.convective?
    %     and/or with child classes for: matter, flow, energy source
    %   - get adjacent / connected nodes (from transfers)
    
    % ALTERNATE NAMES: node
    % ANALOGOUS TO: matter.store / matter.phase ??
        
    properties (SetAccess = protected) %, Abstract)
        
        % Object properties
        
        sName; % This object's name.
        
        
        % Internal properties
        
        % Associated objects
        sMatterClass;  % The class of the associated matter object, e.g. phase, store, or dummy.
        oMatterObject; % A matter object representing this capacity.
        oHeatSource;   % A heatsource object attached to this capacity.
        
        
        % Overloaded properties of associated objects
        
        % Overloading oMatterObject properties.
        fTemperature = -1;
        fOverloadedTotalHeatCapacity = -1;
        
    end
    
    properties (Transient, SetAccess = protected)
        
        fEnergyDiff = 0; %FIXUP: for logging only
        
    end
    
    methods
        
        function this = Capacity(sIdentifier, oMatterObject)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated matter
            %   instance.
            
            % Set name of Capacity.
            this.sName = sIdentifier;
            
            % Set associated objects.
            this.setMatterObject(oMatterObject);
            
        end
        
        function changeInnerEnergy(this, fEnergyChange)
            
            this.fEnergyDiff = fEnergyChange;
            
            if isnan(fEnergyChange)
                if this.fOverloadedTotalHeatCapacity ~= Inf
                    this.warn('thermal:capacity:changeInnerEnergy', 'Received NaN energy change but node "%s" has a finite capacity.', this.sName);
                end
                return; % Skip the rest.
            end
            
            % If heat capacity is overloaded, do not pass the heat change
            % along to the matter object but overload the temperature.
            if this.fOverloadedTotalHeatCapacity ~= -1
                fNewTemp = this.getTemperature() + fEnergyChange / this.getTotalHeatCapacity();
                this.setTemperature(fNewTemp, true); % Overload temperature.
                return; % We're done here.
            end
            
            % Forward call to matter object.
            this.oMatterObject.changeInnerEnergy(fEnergyChange);
            
        end
        
        function setHeatSource(this, oHeatSource)
            % Set the heat source object of this capacity. 
            
            % Is oHeatSource an instance of thermal.HeatSource?
            if ~isa(oHeatSource, 'thermal.HeatSource')
                this.throw('capacity:setHeatSource', 'This is no heat source!');
            end
            
            % Store heat source object instance.
            this.oHeatSource = oHeatSource;
            
        end
        
        function overloadTotalHeatCapacity(this, fTotalHeatCapacity, ~) %bOverload)
            % Overload the heat capacity of the associated matter object.
            % (Always overload if this function is called.)
            
            this.fOverloadedTotalHeatCapacity = fTotalHeatCapacity;
            
        end
        
        function fHeatCapacity = getTotalHeatCapacity(this, bForceMatterRead)
            % Get the heat capacity of the associated matter object OR the
            % overloaded property set by the capacity if |bForceMatterRead|
            % is not set or false. 
            
            % Set the default value of the second parameter to |false|.
            if nargin < 2
                bForceMatterRead = false;
            end
            
            % Was the heat capacity overloaded and is it ok to return the
            % overloaded capacity? ...
            if this.fOverloadedTotalHeatCapacity ~= -1 && ~bForceMatterRead
                % ... then return the overloaded capacity.
                fHeatCapacity = this.fOverloadedTotalHeatCapacity;
            else
                % Otherwise load the capacity from the associated matter
                % object.
                fHeatCapacity = this.oMatterObject.getTotalHeatCapacity();
            end
            
        end
        
        function fHeaterPower = getHeatPower(this)
            
            if ~isempty(this.oHeatSource) && isvalid(this.oHeatSource)
                % Get current power of heat source.
                fHeaterPower = this.oHeatSource.getPower();
            else
                % Without an attached heat source, the heater power is 
                % |0 W|.
                fHeaterPower = 0;
            end
            
        end
        
        function setTemperature(this, fTemperature, bOverload)
            
            if nargin > 2 && bOverload
                this.fTemperature = fTemperature;
                return; % We're done here.
            end
            
            this.warn('capacity:setTemperature', 'You may not want to do this. Use "changeInnerEnergy" instead.');
            
            %TODO: remove
            try
                this.oMatterObject.setTemperature(fTemperature);
            catch
                this.oMatterObject.fTemperature = fTemperature;
            end
            
        end
        
        function fTemperature = getTemperature(this, bForceMatterRead)
            % Get the current temperature of the associated matter object
            % OR the overloaded property set by the capacity if
            % |bForceMatterRead| is not set or false. 
            
            % Set the default value of the second parameter to |false|.
            if nargin < 2
                bForceMatterRead = false;
            end
            
            % Was the heat capacity overloaded and is it ok to return the
            % overloaded capacity? ...
            if this.fTemperature ~= -1 && ~bForceMatterRead
                % ... then return the overloaded capacity.
                fTemperature = this.fTemperature;
            else
                % Otherwise load the capacity from the associated matter
                % object.
                %TODO: fix bottleneck
                try
                    fTemperature = this.oMatterObject.getTemperature();
                catch
                    fTemperature = this.oMatterObject.fTemperature;
                end
            end
            
        end
        
    end
    
    methods (Access = protected)
        % The following methods may require a call to |this.updateState()| 
        % after invocation to propagate the object's properties to the 
        % thermal object instance.
        
        function setMatterObject(this, oMatterObject)
            % Check the associated matter object of this capacity and run
            % the "class of matter"-specific loader method.
            
            % TODO: flow processors?
            
            if isa(oMatterObject, 'thermal.DummyMatter')
                
                this.sMatterClass = 'dummy';
                this.loadDummyCapacity(oMatterObject);
                
            elseif isa(oMatterObject, 'matter.phase')
                
                this.sMatterClass = 'phase';
                this.loadPhaseCapacity(oMatterObject);
                
            elseif isa(oMatterObject, 'matter.store')
                
                this.sMatterClass = 'store';
                this.loadStoreCapacity(oMatterObject);
                
            else
                
                % fall through: fail
                this.throw('Capacity:setMatterObject', 'Invalid object provided, should be an instance of |matter.phase| or |matter.store|!');
                
            end
            
        end
        
        function loadPhaseCapacity(this, oMatterPhase)
            % This method is called from |this.setMatterObject| when the
            % matter object is an instance of |matter.phase|.
            %TODO: do some initialization here?
            
            this.oMatterObject = oMatterPhase;
            
        end
        
        function loadStoreCapacity(this, oMatterStore)
            % This method is called from |this.setMatterObject| when the
            % matter object is an instance of |matter.store|.
            %TODO: do some initialization here?
            
            this.oMatterObject = oMatterStore;
            
            this.warn('capacity:loadStoreCapacity', 'Using stores as capacity objects may fail (e.g. no |changeInnerEnergy| method).');
            
        end
        
        function loadDummyCapacity(this, oDummyMatter)
            % This method is called from |this.setMatterObject| when the
            % matter object is an instance of |thermal.DummyMatter|.
            %TODO: do some initialization here?
            
            this.oMatterObject = oDummyMatter;
            
        end
        
        % TODO: createFromFlow() ??
        
    end
    
end
