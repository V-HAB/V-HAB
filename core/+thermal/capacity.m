classdef capacity < base
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
        oHeatSource; % = struct('fPower', 0);   % A heatsource object attached to this capacity.
        
        
        % Overloaded properties of associated objects
        
        % Overloading oMatterObject properties.
        %fTemperature = -1;
        %fOverloadedTotalHeatCapacity = -1;
        
        bBoundary = false;
        
        
        % Local values, copied from ref objs
%         fTemperature = 0;
%         fTotalHeatCapacity = inf;
%         fHeatPower = 0;
    end
    
    properties (Transient, SetAccess = protected)
        
        fEnergyDiff = 0; %FIXUP: for logging only
        
    end
    
    methods
        
        function this = capacity(sIdentifier, oMatterObject)
            %CAPACITY Create new thermal capacity object
            %   Create a new capacity with a name and associated matter
            %   instance.
            
            % Set name of capacity.
            this.sName = sIdentifier;
            
            % Set associated objects.
            this.setMatterObject(oMatterObject);
            
        end
        
        function changeInnerEnergy(this, fEnergyChange)
            
            this.fEnergyDiff = fEnergyChange;
            
            if isnan(fEnergyChange) && ~this.bBoundary
                
% % %                 oMain = this.oMatterObject.oStore.oContainer.oRoot.toChildren.thermal_layer;
% % %                 oNode = oMain.toChildren.arm_left.toChildren.lower.toChildren.node_2;
% % %                 
% % %                 fprintf('MET %f, TEMP ENV %f, ALPHA %f, VASO %f\n', oMain.fMetabolicLoad, oMain.fInitialTemperatureModule, oNode.fAlphaSkinToAir, oNode.rInitialBloodFlowDistribution);
                
                
%                 if this.fOverloadedTotalHeatCapacity ~= Inf
                    this.warn('thermal:capacity:changeInnerEnergy', 'Received NaN energy change but node "%s" has a finite capacity.', this.sName);
%                 end
                return; % Skip the rest.
            end
            
            % If heat capacity is overloaded, do not pass the heat change
            % along to the matter object but overload the temperature.
            %if this.fOverloadedTotalHeatCapacity ~= -1
            if this.bBoundary
%                 fNewTemp = this.getTemperature() + fEnergyChange / this.getTotalHeatCapacity();
%                 this.setTemperature(fNewTemp, true); % Overload temperature.
                return; % We're done here.
            end
            
            % Forward call to matter object.
            this.oMatterObject.changeInnerEnergy(fEnergyChange);
            
            
            %%%
%             this.updateLocalHeatPower();
%             this.updateLocalTotalHeatCapacity();
%             this.updateLocalTemperature();
        end
        
        function setHeatSource(this, oHeatSource)
            % Set the heat source object of this capacity. 
            
            % Is oHeatSource an instance of thermal.heatsource?
            if ~isa(oHeatSource, 'thermal.heatsource')
                this.throw('capacity:setHeatSource', 'This is no heat source!');
            end
            
            % Store heat source object instance.
            this.oHeatSource = oHeatSource;
            
            
            %%%
%             this.oHeatSource.bind('update', @this.updateLocalHeatPower);
%             this.updateLocalHeatPower();
        end
        
%         function overloadTotalHeatCapacity(this, fTotalHeatCapacity, ~) %bOverload)
%             % Overload the heat capacity of the associated matter object.
%             % (Always overload if this function is called.)
%             
%             this.fOverloadedTotalHeatCapacity = fTotalHeatCapacity;
%             
%         end
        
        function fTotalHeatCapacity = getTotalHeatCapacity(this)%, bForceMatterRead)
            
            %%%this.warn('getTotalHeatCapacity', 'Access fTotalHeatCapacity directly!');
            
            % Get the heat capacity of the associated matter object OR the
            % overloaded property set by the capacity if |bForceMatterRead|
            % is not set or false. 
            
%             % Set the default value of the second parameter to |false|.
%             if nargin < 2
%                 bForceMatterRead = false;
%             end
            
            % Was the heat capacity overloaded and is it ok to return the
            % overloaded capacity? ...
%             if this.fOverloadedTotalHeatCapacity ~= -1 && ~bForceMatterRead
%                 % ... then return the overloaded capacity.
%                 fHeatCapacity = this.fOverloadedTotalHeatCapacity;
%             else
                % Otherwise load the capacity from the associated matter
                % object.
%                 fHeatCapacity = this.oMatterObject.getTotalHeatCapacity();
%             end
            if this.bBoundary
                fTotalHeatCapacity = Inf;
            else
                fTotalHeatCapacity = this.oMatterObject.fTotalHeatCapacity; %getTotalHeatCapacity();
            end
            
        end
        
        function fHeaterPower = getHeatPower(this)
            
            %%%this.warn('getHeatPower', 'Access fHeatPower directly!');
            
            if ~isempty(this.oHeatSource) && isvalid(this.oHeatSource)
                % Get current power of heat source.
                %fHeaterPower = this.oHeatSource.getPower();
                fHeaterPower = this.oHeatSource.fPower;
            else
                % Without an attached heat source, the heater power is 
                % |0 W|.
                fHeaterPower = 0;
            end
            
        end
        
%         function setTemperature(this, fTemperature, bOverload)
%             
%             if nargin > 2 && bOverload
%                 this.fTemperature = fTemperature;
%                 return; % We're done here.
%             end
%             
%             this.warn('capacity:setTemperature', 'You may not want to do this. Use "changeInnerEnergy" instead.');
%             
%             %TODO: remove
%             try
%                 this.oMatterObject.setTemperature(fTemperature);
%             catch
%                 this.oMatterObject.fTemperature = fTemperature;
%             end
%             
%         end
        
        function fTemperature = getTemperature(this)%, bForceMatterRead)
            
            %%%this.warn('getTemperature', 'Access fTemperature directly!');
            
            % Get the current temperature of the associated matter object
            % OR the overloaded property set by the capacity if
            % |bForceMatterRead| is not set or false. 
            
            % Set the default value of the second parameter to |false|.
%             if nargin < 2
%                 bForceMatterRead = false;
%             end
            
            % Was the heat capacity overloaded and is it ok to return the
            % overloaded capacity? ...
%             if this.fTemperature ~= -1 && ~bForceMatterRead
%                 % ... then return the overloaded capacity.
%                 fTemperature = this.fTemperature;
%             else
                % Otherwise load the capacity from the associated matter
                % object.
                %TODO: fix bottleneck
                %try
                %    fTemperature = this.oMatterObject.getTemperature();
                %catch
                    fTemperature = this.oMatterObject.fTemperature;
                %end
%             end
            
        end
        
        function makeBoundaryNode(this)
            this.bBoundary = true;
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
            
            if isa(oMatterObject, 'thermal.dummymatter')
                
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
                this.throw('capacity:setMatterObject', 'Invalid object provided, should be an instance of |matter.phase| or |matter.store|!');
                
            end
            
        end
        
        function loadPhaseCapacity(this, oMatterPhase)
            % This method is called from |this.setMatterObject| when the
            % matter object is an instance of |matter.phase|.
            %TODO: do some initialization here?
            
            this.oMatterObject = oMatterPhase;
            
            % If boundary node, total heat capacity will remain inf
            %%%
%             if ~this.bBoundary
%                 this.oMatterObject.bind('update.post', @this.updateLocalTotalHeatCapacity);
%                 this.updateLocalTotalHeatCapacity();
%             end
%             
%             this.oMatterObject.bind('massupdate.post', @this.updateLocalTemperature);
%             this.updateLocalTemperature();
            
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
            % matter object is an instance of |thermal.dummymatter|.
            %TODO: do some initialization here?
            
            this.oMatterObject = oDummyMatter;
            
            %%%
%             if ~this.bBoundary
%                 this.oMatterObject.bind('update', @this.updateLocalTotalHeatCapacity);
%                 this.updateLocalTotalHeatCapacity();
%             end
%             
%             this.oMatterObject.bind('update', @this.updateLocalTemperature);
%             this.updateLocalTemperature();
            
        end
        
        % TODO: createFromFlow() ??
        
        
        %%%
%         function updateLocalHeatPower(this, ~)
%             if ~isempty(this.oHeatSource) && isvalid(this.oHeatSource)
%                 % Get current power of heat source.
%                 this.fHeatPower = this.oHeatSource.fPower;
%             end
%         end
%         
%         function updateLocalTotalHeatCapacity(this, ~)
%             this.fTotalHeatCapacity = this.oMatterObject.fTotalHeatCapacity;
%         end
%         
%         function updateLocalTemperature(this, ~)
%             this.fTemperature = this.oMatterObject.fTemperature;
%         end
    end
    
end
