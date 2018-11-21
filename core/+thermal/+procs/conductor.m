classdef (Abstract) conductor < base & event.source
    %CONDUCTOR A thermal connection between two capacity objects
    %   Detailed explanation goes here
    % 
    % ANALOGOUS TO: matter.proc
    
    properties (SetAccess = protected)
        
        % Object properties
        
        sName; % The name of the transfer object. Usually a combination of its associated capacity objects' names.
        
        % Internal properties
        
        oLeft;  % The "left" side of the connection.
        oRight; % The "right" side of the connection.
        
        oContainer;
        
        oThermalBranch;
        
        oMT;
        oTimer;
        
        bSealed = false;
        
        % The thermal solver will need to determine which type of
        % conductor a specific object is. Since isa() is very slow, we
        % create these three boolean variables. 
        bRadiative  = false;
        bConvective = false;
        bConductive = false;
    end
    
    properties (Abstract, SetAccess = protected)
        fResistance; % Thermal resistance of connection (unit depends on subclass).
        
    end
    
    
    methods
        
        function this = conductor(oContainer, sName)
            % Create a conductive conductor instance and store the name, 
            % associated capacities as well as the (intial) conductivity
            % value.
            
            this.sName = sName;
            this.oContainer = oContainer;
            
            this.oContainer.addProcConductor(this);
            
            this.oMT    = this.oContainer.oMT;
            this.oTimer = this.oContainer.oTimer;
            
        end
        
        
        function seal(this, oThermalBranch)
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            % Making sure that the object is configured properly in terms
            % of it's type.
            if sum([this.bRadiative this.bConductive this.bConvective]) > 1
                this.throw('seal', 'You have configured the conductor ''%s'' to be of multiple types. Can only be one (radiative, conductive or convective).', this.sName);
            end
            
            this.oThermalBranch = oThermalBranch;
            %this.oMT     = oBranch.oMT;
            this.bSealed = true;
        end
    end
    
end

