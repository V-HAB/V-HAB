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
    end
    
    properties (Abstract, SetAccess = protected)
        fConductivity; % Thermal conductivity of connection (unit depends on subclass).
        
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
            
            this.oThermalBranch = oThermalBranch;
            %this.oMT     = oBranch.oMT;
            this.bSealed = true;
        end
    end
    
end

